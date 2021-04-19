
import moment from 'moment'

API.add 'service/oab/deposit',
  get:
    authOptional: true
    action: () ->
      return if not this.queryParams.url then false else API.service.oab.deposit undefined, this.queryParams, API.http.getFiles(this.queryParams.url), this.userId
  post:
    authOptional: true
    action: () ->
      return API.service.oab.deposit undefined, this.bodyParams, this.request.files, this.userId

_deposits = (params,uid,deposited,csv) ->
  restrict = [{exists:{field:'deposit.type'}}]
  restrict.push({term:{'deposit.from.exact':(params.uid ? uid)}}) if uid or params.uid
  restrict.push({exists:{field:'deposit.zenodo.url'}}) if deposited
  delete params.uid if params.uid?
  params.size ?= 10000
  params.sort ?= 'createdAt:asc'
  fields = ['metadata','permissions.permissions','permissions.ricks','permissions.best_permission','permissions.file','deposit','url']
  if params.fields
    fields = params.fields.split ','
    delete params.fields
  res = oab_catalogue.search params, {restrict:restrict}
  re = []
  for r in res.hits.hits
    dr = r._source
    if csv and dr.metadata?.reference?
      delete dr.metadata.reference
    if csv and dr.error
      try
        dr.error = dr.error.split(':')[0].split('{')[0].trim()
      catch
        delete dr.error
    if csv and dr.metadata?.author?
      for a of dr.metadata.author
        dr.metadata.author[a] = if dr.metadata.author[a].name then dr.metadata.author[a].name else if dr.metadata.author[a].given and dr.metadata.author[a].family then dr.metadata.author[a].given + ' ' + dr.metadata.author[a].family else ''
    for d in dr.deposit
      if ((not uid? and not params.uid?) or d.from is params.uid or d.from is uid) and (not deposited or d.zenodo?.file?)
        red = {doi: dr.metadata.doi, title: dr.metadata.title, type: d.type, createdAt: d.createdAt}
        already = false
        if deposited
          red.file = d.zenodo.file
          for ad in re
            if ad.doi is red.doi and ad.file is red.file
              already = true
              break
        if not already
          for f in fields
            if f not in ['metadata.doi','metadata.title','deposit.type','deposit.createdAt','metadata.reference']
              if f is 'deposit'
                red[f] = d
              else
                red[f] = API.collection.dot dr, f
          re.push red
  if params.sort is 'createdAt:asc'
    re = _.sortBy re, 'createdAt'
  if 'deposit.createdAt' not in fields
    for dr in re
      delete dr.createdAt
  if csv
    for f of re
      re[f] = API.collection.flatten re[f]
  return re

API.add 'service/oab/deposits',
  csv: true
  get:
    authOptional: true
    action: () -> return _deposits this.queryParams, this.userId, undefined, this.request.url.indexOf('.csv') isnt -1
  post:
    authOptional: true
    action: () ->
      restrict = [{exists:{field:'deposit.type'}}]
      restrict.push({term:{'deposit.from.exact':(this.queryParams.uid ? this.userId)}}) if this.userId or this.queryParams.uid
      delete this.queryParams.uid if this.queryParams.uid?
      return oab_catalogue.search this.bodyParams, {restrict:restrict}
API.add 'service/oab/deposited',
  csv: true
  get:
    authOptional: true
    action: () -> return _deposits this.queryParams, this.userId, true, this.request.url.indexOf('.csv') isnt -1

API.add 'service/oab/deposit/config',
  get:
    authOptional: true
    action: () ->
      try
        return API.service.oab.deposit.config this.queryParams.uid ? this.user._id ? this.queryParams.url
      return 404
  post:
    authRequired: 'openaccessbutton.user'
    action: () ->
      opts = this.request.body ? {}
      for o of this.queryParams
        opts[o] = this.queryParams[o]
      if opts.uid and API.accounts.auth 'openaccessbutton.admin', this.user
        user = API.accounts.retrieve opts.uid
        delete opts.uid
      else
        user = this.user
      return API.service.oab.deposit.config user, opts

API.add 'service/oab/deposit/url', 
  get: 
    authOptional: true
    action: () -> 
      return API.service.oab.deposit.url this.queryParams.uid ? this.userId



# for legacy
API.add 'service/oab/receive/:rid',
  get: () -> return if r = oab_request.find({receiver:this.urlParams.rid}) then r else 404
  post:
    authOptional: true
    action: () ->
      if r = oab_request.find {receiver:this.urlParams.rid}
        admin = this.bodyParams.admin and this.userId and API.accounts.auth('openaccessbutton.admin',this.user)
        return API.service.oab.receive this.urlParams.rid, this.request.files, this.bodyParams.url, this.bodyParams.title, this.bodyParams.description, this.bodyParams.firstname, this.bodyParams.lastname, undefined, admin
      else
        return 404

# for legacy
API.add 'service/oab/receive/:rid/:holdrefuse',
  get: () ->
    if r = oab_request.find {receiver:this.urlParams.rid}
      if this.urlParams.holdrefuse is 'refuse'
        if this.queryParams.email is r.email
          API.service.oab.refuse r._id, this.queryParams.reason
        else
          return 401
      else
        if isNaN(parseInt(this.urlParams.holdrefuse))
          return 400
        else
          API.service.oab.hold r._id, parseInt(this.urlParams.holdrefuse)
      return true
    else
      return 404




API.service.oab.deposit = (d, options={}, files, uid) ->
  options = API.tdm.clean options
  if typeof d is 'string' # a catalogue ID
    d = oab_catalogue.get d
  else
    d = oab_catalogue.finder options.metadata ? options
    if not d? and options.metadata?
      fnd = API.service.oab.find options.metadata # this will create a catalogue record out of whatever is provided, and also checks to see if thing is available already
      d = oab_catalogue.get fnd.catalogue
  return 400 if not d?

  d.deposit ?= []
  dep = {createdAt: Date.now(), zenodo: {}}
  dep.created_date = moment(dep.createdAt, "x").format "YYYY-MM-DD HHmm.ss"
  dep.embedded = options.embedded if options.embedded
  dep.demo = options.demo if options.demo
  dep.pilot = options.pilot if options.pilot
  if typeof dep.pilot is 'boolean' or dep.pilot in ['true','false'] # catch possible old erros with live/pilot values
    dep.pilot = if dep.pilot is true or dep.pilot is 'true' then Date.now() else undefined
  dep.live = options.live if options.live
  if typeof dep.live is 'boolean' or dep.live in ['true','false']
    dep.live = if dep.live is true or dep.live is 'true' then Date.now() else undefined
  dep.name = (files[0].filename ? files[0].name) if files? and files.length
  dep.email = options.email if options.email
  dep.from = options.from if options.from
  dep.from = uid if uid and (not dep.from? or dep.from is 'anonymous')
  dep.plugin = options.plugin if options.plugin
  dep.confirmed = decodeURIComponent(options.confirmed) if options.confirmed

  uc = if options.config? then (if typeof options.config is 'string' then JSON.parse(options.config) else options.config) else if dep.from? and dep.from isnt 'anonymous' then API.service.oab.deposit.config(dep.from) else false

  perms = API.service.oab.permission d, files, undefined, dep.confirmed # if confirmed is true the submitter has confirmed this is the right file. If confirmed is the checksum this is a resubmit by an admin
  if perms.file?.archivable and ((dep.confirmed? and dep.confirmed is perms.file.checksum) or not dep.confirmed) #or (dep.confirmed and API.settings.dev)) # if the depositor confirms we don't deposit, we manually review - only deposit on admin confirmation (but on dev allow it)
    zn = {}
    zn.content = files[0].data
    zn.name = perms.file.name
    zn.publish = API.settings.service.openaccessbutton?.deposit?.zenodo is true
    creators = []
    try
      for a in d.metadata.author
        if a.family?
          at = {name: a.family + (if a.given then ', ' + a.given else '')}
          try at.orcid = a.ORCID.split('/').pop() if a.ORCID
          try at.affiliation = a.affiliation.name if typeof a.affiliation is 'object' and a.affiliation.name?
          creators.push at 
    creators = [{name:'Unknown'}] if creators.length is 0
    description = if d.metadata.abstract then d.metadata.abstract + '<br><br>' else ''
    description += perms.best_permission?.deposit_statement ? (if d.metadata.doi? then 'The publisher\'s final version of this work can be found at https://doi.org/' + d.metadata.doi else '')
    description = description.trim()
    description += '.' if description.lastIndexOf('.') isnt description.length-1
    description += ' ' if description.length
    description += '<br><br>Deposited by shareyourpaper.org and openaccessbutton.org. We\'ve taken reasonable steps to ensure this content doesn\'t violate copyright. However, if you think it does you can request a takedown by emailing help@openaccessbutton.org.'
    meta =
      title: d.metadata.title ? 'Unknown',
      description: description.trim(),
      creators: creators,
      version: if perms.file.version is 'preprint' then 'Submitted Version' else if perms.file.version is 'postprint' then 'Accepted Version' else if perms.file.version is 'publisher pdf' then 'Published Version' else 'Accepted Version',
      journal_title: d.metadata.journal
      journal_volume: d.metadata.volume
      journal_issue: d.metadata.issue
      journal_pages: d.metadata.page
    meta.keywords = d.metadata.keyword if _.isArray(d.metadata.keyword) and d.metadata.keyword.length and typeof d.metadata.keyword[0] is 'string'
    if d.metadata.doi?
      in_zenodo = API.use.zenodo.records.doi d.metadata.doi
      if in_zenodo and dep.confirmed isnt perms.file.checksum and not API.settings.dev
        dep.zenodo.already = in_zenodo.id # we don't put it in again although we could with doi as related field - but leave for review for now
      else if in_zenodo
        meta['related_identifiers'] = [{relation: (if meta.version is 'postprint' or meta.version is 'AAM' or meta.version is 'preprint' then 'isPreviousVersionOf' else 'isIdenticalTo'), identifier: d.metadata.doi}]
      else
        meta.doi = d.metadata.doi
    else if API.settings.service.openaccessbutton?.zenodo?.prereserve_doi
      meta.prereserve_doi = true
    meta['access_right'] = 'open'
    meta.license = perms.best_permission?.licence ? 'cc-by' # zenodo also accepts other-closed and other-nc, possibly more
    meta.license = 'other-closed' if meta.license.indexOf('other') isnt -1 and meta.license.indexOf('closed') isnt -1
    meta.license = 'other-nc' if meta.license.indexOf('other') isnt -1 and meta.license.indexOf('non') isnt -1 and meta.license.indexOf('commercial') isnt -1
    meta.license += '-4.0' if meta.license.toLowerCase().indexOf('cc') is 0 and isNaN(parseInt(meta.license.substring(meta.license.length-1)))
    try
      if perms.best_permission?.embargo_end and moment(perms.best_permission.embargo_end,'YYYY-MM-DD').valueOf() > Date.now()
        meta['access_right'] = 'embargoed'
        meta['embargo_date'] = perms.best_permission.embargo_end # check date format required by zenodo
    try meta['publication_date'] = d.metadata.published if d.metadata.published? and typeof d.metadata.published is 'string'
    if uc isnt false
      uc.community = uc.community_ID if uc.community_ID? and not uc.community?
      if uc.community
        uc.communities ?= []
        uc.communities.push({identifier: ccm}) for ccm in (if typeof uc.community is 'string' then uc.community.split(',') else uc.community)
      if uc.community? or uc.communities?
        uc.communities ?= uc.community
        uc.communities = [uc.communities] if not Array.isArray uc.communities
        meta['communities'] = []
        meta.communities.push(if typeof com is 'string' then {identifier: com} else com) for com in uc.communities
    tk = if API.settings.dev or dep.demo then API.settings.service.openaccessbutton?.zenodo?.sandbox else API.settings.service.openaccessbutton?.zenodo?.token
    if tk
      if not dep.zenodo.already
        z = API.use.zenodo.deposition.create meta, zn, tk
        if z.id
          dep.zenodo.id = z.id
          dep.zenodo.url = 'https://' + (if API.settings.dev or dep.demo then 'sandbox.' else '') + 'zenodo.org/record/' + z.id
          dep.zenodo.doi = z.metadata.prereserve_doi.doi if z.metadata?.prereserve_doi?.doi?
          dep.zenodo.file = z.uploaded?.links?.download ? z.uploaded?.links?.download
        else
          dep.error = 'Deposit to Zenodo failed'
          try dep.error += ': ' + JSON.stringify z
    else
      dep.error = 'No Zenodo credentials available'
  dep.version = perms.file.version if perms.file?.version?
  if dep.zenodo.id
    if perms.best_permission?.embargo_end and moment(perms.best_permission.embargo_end,'YYYY-MM-DD').valueOf() > Date.now()
      dep.embargo = perms.best_permission.embargo_end
    dep.type = 'zenodo'
  else if dep.error? and dep.error.toLowerCase().indexOf('zenodo') isnt -1
    dep.type = 'review'
  else if options.from and (not dep.embedded or (dep.embedded.indexOf('openaccessbutton.org') is -1 and dep.embedded.indexOf('shareyourpaper.org') is -1))
    dep.type = if options.redeposit then 'redeposit' else if files? and files.length then 'forward' else 'dark'
  else
    dep.type = 'review'
  d.deposit.push dep
  dd = {deposit: d.deposit, permissions: perms}
  oab_catalogue.update d._id, dd

  bcc = API.settings.service.openaccessbutton.notify.deposit ? ['joe@righttoresearch.org','natalia.norori@openaccessbutton.org']
  #bcc = []
  #if dep.type isnt 'review'
  #  bcc = tos
  #  tos = []
  tos = []
  if typeof uc?.owner is 'string' and uc.owner.indexOf('@') isnt -1
    tos.push uc.owner
  else if dep.from and dep.from isnt 'anonymous' and iacc = API.accounts.retrieve dep.from
    try tos.push iacc.email ? iacc.emails[0].address # the institutional user may set a config value to use as the contact email address but for now it is the account address
  if tos.length is 0
    tos = _.clone bcc
    bcc = []

  dep.permissions = perms
  dep.metadata = d.metadata
  dep.url = if typeof options.redeposit is 'string' then options.redeposit else if d.url then d.url else undefined

  ed = _.clone dep
  if ed.metadata?.author?
    as = []
    for author in ed.metadata.author
      if author.family
        as.push (if author.given then author.given + ' ' else '') + author.family
    ed.metadata.author = as
  ed.adminlink = (if ed.embedded then ed.embedded else 'https://shareyourpaper.org' + (if ed.metadata?.doi? then '/' + ed.metadata.doi else ''))
  ed.adminlink += if ed.adminlink.indexOf('?') is -1 then '?' else '&'
  if perms?.file?.checksum?
    ed.confirmed = encodeURIComponent perms.file.checksum
    ed.adminlink += 'confirmed=' + ed.confirmed + '&'
  ed.adminlink += 'email=' + ed.email
  tmpl = API.mail.template dep.type + '_deposit.html'
  sub = API.service.oab.substitute tmpl?.content, ed
  if perms.file?.archivable isnt false # so when true or when undefined if no file is given
    ml =
      from: 'deposits@openaccessbutton.org'
      to: tos
      subject: (sub.subject ? dep.type + ' deposit')
      html: sub.content
    ml.bcc = bcc if bcc.length # passing undefined to mail seems to cause errors, so only set if definitely exists
    ml.attachments = [{filename: (files[0].filename ? files[0].name), content: files[0].data}] if _.isArray(files) and files.length
    API.service.oab.mail ml

  # eventually this could also close any open requests for the same item, but that has not been prioritised to be done yet
  dep.z = z if API.settings.dev and dep.zenodo.id? and dep.zenodo.id isnt 'EXAMPLE'
  
  if dep.embargo
    try dep.embargo_UI = moment(dep.embargo).format "Do MMMM YYYY"
  return dep

API.service.oab.deposit.config = (user, config) ->
  if typeof user is 'string' and user.indexOf('.') isnt -1 # user is actually url where an embed has been called from
    try
      res = oab_find.search q
      res = oab_find.search 'plugin.exact:shareyourpaper AND config:* AND embedded:"' + user.split('?')[0].split('#')[0] + '"'
      return JSON.parse res.hits.hits[0]._source.config
    catch
      return {}
  else
    user = Users.get(user) if typeof user is 'string'
    if typeof user is 'object' and config?
      # ['depositdate','community','institution_name','repo_name','email_domains','terms','old_way','deposit_help','email_for_manual_review','file_review_time','if_no_doi_go_here','email_for_feedback','sayarticle','oa_deposit_off','library_handles_dark_deposit_requests','dark_deposit_off','ror','live','pilot','activate_try_it_and_learn_more','not_library']
      config.pilot = Date.now() if config.pilot is true
      config.live = Date.now() if config.live is true
      try config.community = config.community.split('communities/')[1].split('/')[0] if typeof config.community is 'string' and config.community.indexOf('communities/') isnt -1
      delete config.autorunparams if config.autorunparams is false
      if JSON.stringify(config).indexOf('<script') is -1
        if not user.service?
          Users.update user._id, {service: {openaccessbutton: {deposit: {config: config, had_old: false}}}}
        else if not user.service.openaccessbutton?
          Users.update user._id, {'service.openaccessbutton': {deposit: {config: config, had_old: false}}}
        else if not user.service.openaccessbutton.deposit?
          Users.update user._id, {'service.openaccessbutton.deposit': {config: config, had_old: false}}
        else
          upd = {'service.openaccessbutton.deposit.config': config}
          if user.service.openaccessbutton.deposit.config? and not user.service.openaccessbutton.deposit.old_config? and user.service.openaccessbutton.deposit.had_old isnt false
            upd['service.openaccessbutton.deposit.old_config'] = user.service.openaccessbutton.deposit.config
          Users.update user._id, upd
    try
      config ?= user.service.openaccessbutton.deposit?.config ? {}
      try config.owner ?= user.email ? user.emails[0].address
      return config
    catch
      return {}

API.service.oab.deposit.url = (uid) ->
  # given a uid, find the most recent URL that this users uid submitted a deposit for
  q = {size: 0, query: {filtered: {query: {bool: {must: [{term: {plugin: "shareyourpaper"}},{term: {"from.exact": uid}}]}}}}}
  q.aggregations = {embeds: {terms: {field: "embedded.exact"}}}
  res = oab_find.search q
  for eu in res.aggregations.embeds.buckets
    eur = eu.key.split('?')[0].split('#')[0]
    if eur.indexOf('shareyourpaper.org') is -1 and eur.indexOf('openaccessbutton.org') is -1
      return eur
  return false



# for legacy - remove once refactored request and OAB receive
API.service.oab.receive = (rid,files,url,title,description,firstname,lastname,cron,admin) ->
  r = oab_request.find {receiver:rid}
  description ?= r.description if typeof r.description is 'string'
  description ?= r.received.description if r.received? and typeof r.received.description is 'string'
  if not r
    return 404
  else if (r.received?.url or r.received?.zenodo) and not admin
    return 400
  else
    today = new Date().getTime()
    r.received ?= {}
    r.received.date ?= today
    r.received.from ?= r.email
    r.received.description ?= description
    r.received.validated ?= false
    r.received.admin = admin
    r.received.cron = cron
    up = {}
    if url?
      r.received.url = url
    else
      if files? and files.length > 0
        up.content = files[0].data
        up.name = files[0].filename
      up.publish = API.settings.service.openaccessbutton?.zenodo?.publish or r.received.admin
      creators = []
      if r.names
        try
          r.names = r.names.replace(/\[/g,'').replace(/\]/g,'').split(',') if typeof r.names is 'string'
          for n in r.names
            creators.push {name: n}
      if creators.length is 0
        creators = [{name:(if lastname or firstname then '' else 'Unknown')}]
        creators[0].name = lastname if lastname
        creators[0].name += (if lastname then ', ' else '') + firstname if firstname
        creators[0].name = r.name if creators[0].name is 'Unknown' and r.name
        if creators[0].name is 'Unknown' and r.author
          try
            for a in r.author
              if a.family and ( creators[0].name is 'Unknown' or r.email.toLowerCase().indexOf(a.family.toLowerCase()) isnt -1 )
                creators[0].name = a.family
                creators[0].name += (if a.family then ', ' else '') + a.given if a.given
      # http://developers.zenodo.org/#representation
      # journal_volume and journal_issue are acceptable too but we don't routinely collect those
      # access_right can be open embargoed restricted closed
      # if embargoed can also provide embargo_date
      # can provide access_conditions which is a string sentence explaining what conditions we will allow access for
      # license can be a string specifying the license type for open or embargoed content, using opendefinition license tags like cc-by
      meta =
        title: title ? (if r.title then r.title else (if r.url.indexOf('h') isnt 0 and r.url.indexOf('1') isnt 0 then r.url else 'Unknown')),
        description: description ? "Deposited from Open Access Button",
        creators: creators,
        doi: r.doi,
        keywords: r.keywords,
        version: 'AAM',
        journal_title: r.journal
      if API.settings.service.openaccessbutton?.zenodo?.prereserve_doi and not r.doi?
        meta.prereserve_doi = true # do this differently as sending false may still have been causing zenodo to give us a doi...
      try meta['access_right'] = r['access_right'] if typeof r['access_right'] is 'string' and r['access_right'] in ['open','embargoed','restricted','closed']
      try meta['embargo_date'] = r['embargo_date'] if r['embargo_date']? and meta['access_right'] is 'embargoed'
      try meta['access_conditions'] = r['access_conditions'] if typeof r['access_conditions'] is 'string'
      try meta.license = r.license if typeof r.license is 'string'
      try meta['publication_date'] = r.published if r.published? and typeof r.published is 'string' and r.length is 10
      z = API.use.zenodo.deposition.create meta, up, API.settings.service.openaccessbutton?.zenodo?.token
      r.received.zenodo = 'https://zenodo.org/record/' + z.id if z.id
      r.received.zenodo_doi = z.metadata.prereserve_doi.doi if z.metadata?.prereserve_doi?.doi?

    oab_request.update r._id, {hold:'$DELETE',received:r.received,status:(if up.publish is false and not r.received.url? then 'moderate' else 'received')}
    API.service.oab.admin(r._id,'successful_upload') if up.publish
    API.mail.send
      service: 'openaccessbutton'
      from: 'natalia.norori@openaccessbutton.org'
      to: API.settings.service.openaccessbutton.notify.receive
      subject: 'Request ' + r._id + ' received' + (if r.received.url? then ' - URL provided' else (if up.publish then ' - file published on Zenodo' else ' - zenodo publish required'))
      text: (if API.settings.dev then 'https://dev.openaccessbutton.org/request/' else 'https://openaccessbutton.org/request/') + r._id
    return {data: r}

API.service.oab.hold = (rid,days) ->
  today = new Date().getTime()
  date = (Math.floor(today/1000) + (days*86400)) * 1000
  r = oab_request.get rid
  r.holds ?= []
  r.holds.push(r.hold) if r.hold
  r.hold = {from:today,until:date}
  r.status = 'hold'
  oab_request.update rid,{hold:r.hold, holds:r.holds, status:r.status}
  #API.mail.send(); # inform requestee that their request is on hold
  return r

API.service.oab.refuse = (rid,reason) ->
  today = new Date().getTime()
  r = oab_request.get rid
  r.holds ?= []
  r.holds.push(r.hold) if r.hold
  delete r.hold
  r.refused ?= []
  r.refused.push({date:today,email:r.email,reason:reason})
  r.status = 'refused'
  delete r.email
  oab_request.update rid, {hold:'$DELETE',email:'$DELETE',holds:r.holds,refused:r.refused,status:r.status}
  #API.mail.send(); # inform requestee that their request has been refused
  return r
