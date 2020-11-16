
# See https://github.com/OAButton/discussion/issues/1516

import crypto from 'crypto'
import moment from 'moment'

API.add 'service/oab/p2',
  get: () ->
    if this.queryParams?.q? or this.queryParams.source? or _.isEmpty this.queryParams
      return oab_permissions.search this.queryParams
    else
      return API.service.oab.permission this.queryParams, this.queryParams.content, this.queryParams.url, this.queryParams.confirmed, this.queryParams.uid
  post: () ->
    if not this.request.files? and typeof this.request.body is 'object' and (this.request.body.q? or this.request.body.source?)
      this.bodyParams[k] ?= this.queryParams[k] for k of this.queryParams
      return oab_permissions.search this.bodyParams
    else
      return API.service.oab.permission this.queryParams, this.request.files ? this.request.body, undefined, this.queryParams.confirmed ? this.bodyParams?.confirmed, this.queryParams.uid

API.add 'service/oab/p2/:issnorpub', 
  get: () ->
    if typeof this.urlParams.issnorpub is 'string' and this.urlParams.issnorpub.indexOf('-') isnt -1 and this.urlParams.issnorpub.indexOf('10.') isnt 0 and this.urlParams.issnorpub.length < 10
      this.queryParams.issn ?= this.urlParams.issnorpub
    else if this.urlParams.issnorpub.indexOf('10.') isnt 0
      this.queryParams.publisher ?= this.urlParams.issnorpub # but this could be a ror too... any way to tell?
    return API.service.oab.permission this.queryParams

API.add 'service/oab/p2/:doi/:doi2', 
  get: () -> 
    this.queryParams.doi ?= this.urlParams.doi + '/' + this.urlParams.doi2
    return API.service.oab.permission this.queryParams
API.add 'service/oab/p2/:doi/:doi2/:doi3',
  get: () -> 
    this.queryParams.doi ?= this.urlParams.doi + '/' + this.urlParams.doi2 + '/' + this.urlParams.doi3
    return API.service.oab.permission this.queryParams

API.add 'service/oab/p2/journal',
  get: () -> return oab_permissions.search this.queryParams, restrict: [exists: field: 'journal']
  post: () -> return oab_permissions.search this.bodyParams, restrict: [exists: field: 'journal']
API.add 'service/oab/p2/journal/:issnorid',
  get: () -> 
    if this.urlParams.issnorid.indexOf('-') is -1 and j = oab_permissions.get this.urlParams.issnorid
      return j
    else if j = oab_permissions.find journal: this.urlParams.issnorid
      return j
    else if this.urlParams.issnorid.indexOf('-') isnt -1
      return API.service.oab.permissions {issn: this.urlParams.issnorid, doi: this.queryParams.doi}

API.add 'service/oab/p2/publisher',
  get: () -> return oab_permissions.search this.queryParams, restrict: [exists: field: 'publisher']
  post: () -> return oab_permissions.search this.bodyParams, restrict: [exists: field: 'publisher']
API.add 'service/oab/p2/publisher/:norid',
  get: () -> 
    if p = oab_permissions.get this.urlParams.norid
      return p
    else if p = oab_permissions.find 'issuer.id': this.urlParams.norid
      return p
    else
      return API.service.oab.permissions {publisher: this.urlParams.norid, doi: this.queryParams.doi, issn: this.queryParams.issn}

API.add 'service/oab/p2/affiliation',
  get: () -> return oab_permissions.search this.queryParams, restrict: [exists: field: 'affiliation']
  post: () -> return oab_permissions.search this.bodyParams, restrict: [exists: field: 'affiliation']
API.add 'service/oab/p2/affiliation/:rororid', # could also be a two letter country code, which is in the same affiliation field as the ROR
  get: () -> 
    if a = oab_permissions.get this.urlParams.rororid
      return a
    else if a = oab_permissions.find 'issuer.id': this.urlParams.rororid
      return a
    else
      # look up the ROR in wikidata - if found, get the qid from the P17 country snak, look up that country qid
      # get the P297 ISO 3166-1 alpha-2 code, search affiliations for that
      return false

API.add 'service/oab/p2/import',
  get: 
    roleRequired: if API.settings.dev then undefined else 'openaccessbutton.admin'
    action: () -> 
      Meteor.setTimeout (() => API.service.oab.permission.import this.queryParams.reload, undefined, this.queryParams.stale), 1
      return true
API.add 'service/oab/p2/test', get: () -> return API.service.oab.permission.test this.queryParams.email



API.service.oab.permission = (meta={}, file, url, confirmed, roruid, getmeta) ->
  overall_policy_restriction = false
  inp = {}
  if typeof meta is 'string'
    meta = if meta.indexOf('10.') is 0 then {doi: meta} else {issn: meta}
  if meta.metadata? # if passed a catalogue object
    inp = meta
    meta = meta.metadata
    
  if meta.affiliation
    meta.ror = meta.affiliation
    delete meta.affiliation
  if meta.journal and meta.journal.indexOf(' ') is -1
    meta.issn = meta.journal
    delete meta.journal
  if meta.publisher and meta.publisher.indexOf(' ') is -1 and meta.publisher.indexOf(',') is -1 and not oab_permissions.find 'issuer.type.exact:"publisher" AND issuer.id:"' + meta.publisher + '"'
    # it is possible this may actually be a ror, so switch to ror just in case - if it still matches nothing, no loss
    meta.ror = meta.publisher
    delete meta.publisher
  
  meta.ror = meta.ror.split(',') if typeof meta.ror is 'string' and meta.ror.indexOf(',') isnt -1
  
  ror = meta.ror ? false
  if ror is false
    uc = if typeof roruid is 'object' then roruid else if typeof roruid is 'string' then API.service.oab.deposit.config(roruid) else undefined
    if (typeof uc is 'object' and uc.ror?) or typeof roruid is 'string'
      ror = uc?.ror ? roruid

  if _.isEmpty(meta) or (meta.issn and (typeof meta.issn isnt 'string' or meta.issn.length < 5 or meta.issn.indexOf('-') is -1)) or (meta.doi and (typeof meta.doi isnt 'string' or meta.doi.indexOf('10.') isnt 0 or meta.doi.indexOf('/') is -1))
    return body: 'No valid DOI, ISSN, or ROR provided', statusCode: 404
    
  # NOTE later will want to find affiliations related to the authors of the paper, but for now only act on affiliation provided as a ror
  # we now always try to get the metadata because joe wants to serve a 501 if the doi is not a journal article
  if getmeta isnt false
    meta = API.service.oab.metadata {metadata: ['crossref_type','issn','publisher','published','year']}, meta
  meta.published = meta.year + '-01-01' if not meta.published and meta.year
  issns = []
  haddoi = meta.doi?
  af = false
  doiex = false
  if meta.issn
    issns.push meta.issn
    if af = academic_journal.find 'issn.exact:"' + meta.issn + '"'
      meta.publisher ?= af.publisher
      meta.doi ?= af.example
      for an in af.issn
        issns.push(an) if an not in issns
    if not meta.doi?
      for alti in issns
        if doiex = API.use.crossref.journals.dois.example meta.issn
          meta.doi = doiex
          break
    if not meta.doi?
      # we still really can't find one, so query crossref works API for a result, which may be slow
      # later this will be a local lookup once we cache it all
      for ani in issns
        fncr = API.use.crossref.works.search {issn: ani}, undefined, 1, 'type:journal-article'
        if fncr?.data? and fncr.data.length
          meta.publisher ?= fncr.data[0].publisher
          meta.doi = fncr.data[0].DOI
          for crisn in fncr.data[0].ISSN ? []
            issns.push(crisn) if crisn not in issns
          break
  if haddoi and meta.crossref_type not in ['journal-article']
    return
      body: 'DOI is not a journal article'
      status: 501
  
  try
    meta.citation = '['
    meta.citation += meta.title + '. ' if meta.title
    meta.citation += meta.journal + ' ' if meta.journal
    meta.citation += meta.volume + (if meta.issue then ', ' else ' ') if meta.volume
    meta.citation += meta.issue + ' ' if meta.issue
    meta.citation += 'p' + (meta.page ? meta.pages) if meta.page? or meta.pages?
    if meta.year or meta.published
      meta.citation += ' (' + (meta.year ? meta.published.split('-')[0]) + ')'
    meta.citation = meta.citation.trim()
    meta.citation += ']'

  cr = false
  
  _prep = (rec) ->
    if rec.embargo_months and (meta.published or meta.year)
      em = moment meta.published ? meta.year + '-01-01'
      em = em.add rec.embargo_months, 'months'
      #if em.isAfter moment() # changed 09112020 by JM request to always add embargo_end if we can calculate it, even if it is in the past.
      rec.embargo_end = em.format "YYYY-MM-DD"
    delete rec.embargo_end if rec.embargo_end is ''
    rec.copyright_name = if rec.copyright_owner is 'publisher' then (if typeof rec.issuer.id is 'string' then rec.issuer.id else rec.issuer.id[0]) else if rec.copyright_owner in ['journal','affiliation'] then (meta.journal ? '') else if (rec.copyright_owner and rec.copyright_owner.toLowerCase().indexOf('author') isnt -1) and meta.author? and meta.author.length and (meta.author[0].name or meta.author[0].family) then (meta.author[0].name ? meta.author[0].family) + (if meta.author.length > 1 then ' et al' else '') else ''
    if rec.copyright_name in ['publisher','journal'] and (cr or meta.doi or rec.provenance?.example)
      if cr is false
        cr = API.use.crossref.works.doi meta.doi ? rec.provenance.example
      if cr?.assertion? and cr.assertion.length
        for a in cr.assertion
          if a.name.toLowerCase() is 'copyright'
            try rec.copyright_name = a.value
            try rec.copyright_name = a.value.replace('\u00a9 ','').replace(/[0-9]/g,'').trim()
    rec.copyright_year = meta.year if rec.copyright_year is '' and meta.year
    #for ds in ['copyright_name','copyright_year']
    #  delete rec[ds] if rec[ds] is ''
    if rec.deposit_statement? and rec.deposit_statement.indexOf('<<') isnt -1
      fst = ''
      for pt in rec.deposit_statement.split '<<'
        if fst is ''
          fst += pt
        else
          eph = pt.split '>>'
          ph = eph[0].toLowerCase()
          swaps = 
            'journal title': 'journal'
            'vol': 'volume'
            'date of publication': 'published'
            '(c)': 'year'
            'article title': 'title'
            'copyright name': 'copyright_name'
          ph = swaps[ph] if swaps[ph]?
          if ph is 'author'
            try fst += (meta.author[0].name ? meta.author[0].family) + (if meta.author.length > 1 then ' et al' else '')
          else
            try fst += meta[ph] ? rec[ph] ? ''
          try fst += eph[1]
      rec.deposit_statement = fst
    if rec._id?
      rec.meta ?= {}
      rec.meta.source = 'https://' + (if API.settings.dev then 'dev.api.cottagelabs.com/service/oab/p2/' else 'api.openaccessbutton.org/permissions/') + (if rec.issuer.type then rec.issuer.type + '/' else '') + rec._id
    if typeof rec.issuer?.has_policy is 'string' and rec.issuer.has_policy.toLowerCase().trim() in ['not publisher','takedown']
      # find out if this should be enacted if it is the case for any permission, or only the best permission
      overall_policy_restriction = rec.issuer.has_policy
    delete rec[d] for d in ['_id','permission_required','createdAt','updatedAt','created_date','updated_date']
    try delete rec.issuer.updatedAt
    return rec

  _score = (rec) ->
    score = if rec.can_archive then 1000 else 0
    if rec.requirements?
      # TODO what about cases where the requirement is met?
      # and HOW is requirement met? we search ROR against issuer, but how does that match with author affiliation?
      # should we even be searching for permissions by ROR, or only using it to calculate the ones we find by some other means?
      # and if it is not met then is can_archive worth anything?
      score -= 10
    else
      score += if rec.version is 'publishedVersion' then 200 else if rec.version is 'acceptedVersion' then 100 else 0
    score -= 5 if rec.licences? and rec.licences.length
    score += if rec.issuer?.type is 'journal' then 5 else if rec.issuer?.type is 'publisher' then 4 else if rec.issuer?.type is 'university' then 3 else if rec.issuer?.type in 'article' then 2 else 0
    score -= 25 if rec.embargo_months and rec.embargo_months >= 36 and (not rec.embargo_end or moment(rec.embargo_end,"YYYY-MM-DD").isBefore(moment()))
    return score

  perms = best_permission: undefined, all_permissions: [], file: undefined
  rors = []
  if meta.ror?
    meta.ror = [meta.ror] if typeof meta.ror is 'string'
    rs = oab_permissions.search 'issuer.id.exact:"' + meta.ror.join('" OR issuer.id.exact:"') + '"'
    for rr in rs?.hits?.hits ? []
      tr = _prep rr._source
      tr.score = _score tr
      rors.push tr

  if issns.length or meta.publisher
    qr = if issns.length then 'issuer.id.exact:"' + issns.join('" OR issuer.id.exact:"') + '"' else ''
    if meta.publisher
      qr += ' OR ' if qr isnt ''
      qr += 'issuer.id:"' + meta.publisher + '"' # how exact/fuzzy can this be
    ps = oab_permissions.search qr
    if ps?.hits?.hits? and ps.hits.hits.length
      for p in ps.hits.hits
        rp = _prep p._source
        rp.score = _score rp
        perms.all_permissions.push rp
  
  if typeof af is 'object' and af.is_oa isnt false
    af.is_oa = true if not af.is_oa? and ('doaj' in af.src or af.wikidata_in_doaj)
    if not af.is_oa? and coa = API.service.academic.journal.is_oa issns, meta.doi
      af = coa
    if af.is_oa
      altoa =
        can_archive: true
        version: 'acceptedVersion' # maybe publishedVersion? what does doaj allow?
        versions: []
        licence: undefined
        licence_terms: ""
        licences: []
        locations: ['institutional repository']
        embargo_months: undefined
        issuer:
          type: 'article'
          has_policy: 'yes'
          id: oad?.doi
        meta:
          creator: ['support@unpaywall.org']
          contributors: ['support@unpaywall.org']
          monitoring: 'Automatic'

      try altoa.licence = af.license[0].type # could have doaj licence info
      altoa.licence ?= af.licence # wikidata licence
      altoa.embargo_months = 0 if 'doaj' in af.src or af.wikidata_in_doaj
      if not altoa.licence and meta.doi and oadoi = API.use.oadoi.doi meta.doi, false
        if oadoi.journal_is_oa and oadoi.best_oa_location?
          # due to https://github.com/OAButton/discussion/issues/1516#issuecomment-725282855
          altoa.licence = oadoi.best_oa_location.license ? 'cc-by-nc-nd'
          altoa.provenance = {oa_evidence: oadoi.best_oa_location.evidence} if oadoi.best_oa_location.evidence?
          altoa.meta.updated = oadoi.best_oa_location.updated if oadoi.best_oa_location.updated?
          altoa.version = oadoi.best_oa_location.version if oadoi.best_oa_location.version?
      else
        altoa.provenance = {oa_evidence: 'In DOAJ'}
      if typeof altoa.licence is 'string'
        altoa.licence = altoa.licence.toLowerCase().trim()
        if altoa.licence.indexOf('cc') is 0
          altoa.licence = altoa.licence.replace(/ /g, '-')
        else if altoa.licence.indexOf('creative') isnt -1
          altoa.licence = if altoa.licence.indexOf('0') isnt -1 or altoa.licence.indexOf('zero') isnt -1 then 'cc0' else if altoa.licence.indexOf('share') isnt -1 then 'ccbysa' else if altoa.licence.indexOf('derivative') isnt -1 then 'ccbynd' else 'ccby'
        else
          delete altoa.licence
      else
        delete altoa.licence
      if altoa.licence
        altoa.licences = [{type: altoa.licence, terms: ""}]
      if altoa.version
        altoa.versions = if altoa.version in ['submittedVersion','preprint'] then ['submittedVersion'] else if altoa.version in ['acceptedVersion','postprint'] then ['submittedVersion', 'acceptedVersion'] else  ['submittedVersion', 'acceptedVersion', 'publishedVersion']
      altoa.score = _score altoa
      perms.all_permissions.push altoa

  # sort rors by score, and sort alts by score, then combine
  if perms.all_permissions.length
    perms.all_permissions = _.sortBy(perms.all_permissions, 'score').reverse()
    # note if enforcement_from is after published date, don't apply the permission. If no date, the permission applies to everything
    for wp in perms.all_permissions
      if not wp.provenance?.enforcement_from
        perms.best_permission = _.clone wp
        break
      else if not meta.published or moment(meta.published,'YYYY-MM-DD').isAfter(moment(wp.provenance.enforcement_from,'DD/MM/YYYY'))
        perms.best_permission = _.clone wp
        break
    if rors.length
      rors = _.sortBy(rors, 'score').reverse()
      for ro in rors
        perms.all_permissions.push ro
        if not perms.best_permission?.author_affiliation_requirement?
          if perms.best_permission?
            if not ro.provenance?.enforcement_from or not meta.published or moment(meta.published,'YYYY-MM-DD').isAfter(moment(ro.provenance.enforcement_from,'DD/MM/YYYY'))
              pb = perms.best_permission
              for key in ['licences', 'versions', 'locations']
                for vl in ro[key]
                  pb[key] ?= []
                  pb[key].push(vl) if vl not in pb[key]
              for l in pb.licences ? []
                pb.licence = l.type if not pb.licence? or l.type.length < pb.licence.length
              pb.version = if 'publishedVersion' in pb.versions or 'publisher pdf' in pb.versions then 'publishedVersion' else if 'acceptedVersion' in pb.versions or 'postprint' in pb.versions then 'acceptedVersion' else 'submittedVersion'
              if pb.embargo_end
                if ro.embargo_end
                  if moment(ro.embargo_end,"YYYY-MM-DD").isBefore(moment(pb.embargo_end,"YYYY-MM-DD"))
                    pb.embargo_end = ro.embargo_end
              pb.can_archive = true if ro.can_archive is true
              pb.requirements ?= {}
              pb.requirements.author_affiliation_requirement = ro.issuer.id
              pb.affiliation = ro.issuer
          #else
            # can the best affiliation permission be the best permission by itself?
            #perms.best_permission = ro # No it can't

  if file? or url?
    # is it possible file will already have been processed, if so can this step be shortened or avoided?
    perms.file = API.service.oab.permission.file file, url, confirmed
    try perms.lantern = API.service.lantern.licence('https://doi.org/' + meta.doi) if not perms.file?.licence and meta.doi? and 'doi.org' not in url
    if perms.file.archivable? and perms.file.archivable isnt true and perms.lantern?.licence? and perms.lantern.licence.toLowerCase().indexOf('cc') is 0
      perms.file.licence = perms.lantern.licence
      perms.file.licence_evidence = {string_match: perms.lantern.match}
      perms.file.archivable = true
      perms.file.archivable_reason = 'We think that the splash page the DOI resolves to contains a ' + perms.lantern.licence + ' licence statement which confirms this article can be archived'
    if perms.file.archivable and not perms.file.licence?
      if perms.best_permission.licence
        perms.file.licence = perms.best_permission.licence
      else if perms.best_permission?.deposit_statement? and perms.best_permission.deposit_statement.toLowerCase().indexOf('cc') is 0
        perms.file.licence = perms.best_permission.deposit_statement
    perms.best_permission.licence ?= perms.file.licence if perms.file.licence
    if not perms.file.archivable and perms.file.version?
      if perms.best_permission?.version? and perms.file.version is perms.best_permission.version
        f.archivable = true
        f.archivable_reason = 'We believe this is a ' + perms.file.version + ' and our permission system says that version can be shared'
      else
        f.archivable_reason ?= 'We believe this file is a ' + perms.file.version + ' version and our permission system does not list that as an archivable version'

  try
    # save any publisher/issn stuff we found for this journal
    if af is false
      af = academic_journal.find 'issn.exact:"' + issns.join('" OR issn.exact:"') + '"'
    if typeof af is 'object'
      misns = false
      for ni in issns
        if ni not in af.issn
          af.issn.push ni
          misns = true
      upd = {}
      upd.example = doiex if doiex and not af.example
      upd.publisher = meta.publisher if meta.publisher and not af.publisher
      upd.issn = af.issn if misns
      if not _.isEmpty upd
        academic_journal.update af._id, upd

  if overall_policy_restriction
    msgs = 
      'not publisher': 'Please find another DOI for this article as this is provided as this doesn’t allow us to find required information like who published it'
    return
      body: if typeof overall_policy_restriction isnt 'string' then overall_policy_restriction else msgs[overall_policy_restriction.toLowerCase()] ? overall_policy_restriction
      status: 501
  else
    return perms



# https://docs.google.com/spreadsheets/d/1qBb0RV1XgO3xOQMdHJBAf3HCJlUgsXqDVauWAtxde4A/edit
API.service.oab.permission.import = (reload=false, src, stale=3600000) ->
  since = Date.now()-86400010 # 1 day and 10ms ago, just to give a little overlap
  
  keys = 
    versionsarchivable: 'versions'
    permissionsrequestcontactemail: 'permissions_contact'
    archivinglocationsallowed: 'locations'
    license: 'licence'
    licencesallowed: 'licences'
    'post-printembargo': 'embargo_months'
    depositstatementrequired: 'deposit_statement'
    copyrightowner: 'copyright_owner' # can be journal, publisher, affiliation or author
    publicnotes: 'notes'
    authoraffiliationrolerequirement: 'requirements.role'
    authoraffiliationrequirement: 'requirements.affiliation'
    authoraffiliationdepartmentrequirement: 'requirements.departmental_affiliation'
    iffundedby: 'requirements.funder'
    fundingproportionrequired: 'requirements.funding_proportion'
    subjectcoverage: 'requirements.subject'
    has_policy: 'issuer.has_policy'
    permissiontype: 'issuer.type'
    parentpolicy: 'issuer.parent_policy'
    contributedby: 'meta.contributors'
    recordlastupdated: 'meta.updated'
    reviewers: 'meta.reviewer'
    addedby: 'meta.creator'
    monitoringtype: 'meta.monitoring'
    policyfulltext: 'provenance.archiving_policy'
    policylandingpage: 'provenance.archiving_policy_splash'
    publishingagreement: 'provenance.sample_publishing_agreement'
    publishingagreementsplash: 'provenance.sample_publishing_splash'
    rights: 'provenance.author_rights'
    embargolist: 'provenance.embargo_list'
    policyfaq: 'provenance.faq'
    miscsource: 'provenance.misc_source'
    enforcementdate: 'provenance.enforcement_from'
    example: 'provenance.example'

  src ?= API.settings.service?.openaccessbutton?.permissions?.sheet
  records = API.use.google.sheets.feed src, stale # get a new sheet if over an hour old
  ready = []
  for rec in records
    nr = 
      can_archive: false
      version: undefined
      versions: undefined
      licence: undefined
      licence_terms: undefined
      licences: undefined
      locations: undefined
      embargo_months: undefined
      embargo_end: undefined
      deposit_statement: undefined
      permission_required: undefined
      permissions_contact: undefined
      copyright_owner: undefined
      copyright_name: undefined
      copyright_year: undefined
      notes: undefined
      requirements: undefined
      issuer: {}
      meta: {}
      provenance: undefined

    try
      rec.recordlastupdated = rec.recordlastupdated.trim()
      if rec.recordlastupdated.indexOf(',') isnt -1
        nd = false
        for dt in rec.recordlastupdated.split ','
          nd = dt.trim() if nd is false or moment(dt.trim(),'DD/MM/YYYY').isAfter(moment(nd,'DD/MM/YYYY'))
        rec.recordlastupdated = nd if nd isnt false
      nr.meta.updated = rec.recordlastupdated
    nr.meta.updatedAt = moment(nr.meta.updated, 'DD/MM/YYYY').valueOf() if nr.meta.updated?

    if reload or not nr.meta.updatedAt? or nr.meta.updatedAt > since
      # reload all, or those where the rec says it has been updated in the last day
      # unfortunately for now there appears to be no way to uniquely identify a record
      # so if ANY show last updated in the last day, reload them all
      reload = true

      # the google feed import will lowercase these key names and remove whitespace, question marks, brackets too, but not dashes
      nr.issuer.id = if rec.id.indexOf(',') isnt -1 then rec.id.split(',') else rec.id
      if typeof nr.issuer.id isnt 'string'
        cids = []
        inaj = false
        for nid in nr.issuer.id
          nid = nid.trim()
          if nr.issuer.type is 'journal' and nid.indexOf('-') isnt -1 and nid.indexOf(' ') is -1
            nid = nid.toUpperCase()
            if af = academic_journal.find 'issn.exact:"' + nid + '"'
              inaj = true
              for an in af.issn
                cids.push(an) if an not in cids
          cids.push(nid) if nid not in cids
        nr.issuer.id = cids
        #if not inaj and nr.issuer.type is 'journal'
          # add the ISSN to the journal index - can't do this yet because permissions doesn't have journal name
          #academic_journal.insert src: 'permissions', issn: nr.issuer.id, title: rec.journal # note these will have no publisher name
      nr.permission_required = rec.has_policy? and rec.has_policy.toLowerCase().indexOf('permission required') isnt -1
  
      for k of rec
        if keys[k] and rec[k]? and rec[k].length isnt 0
          #console.log k
          nk = keys[k]
          nv = undefined
          if k is 'post-printembargo' # Post-Print Embargo - empty or number of months like 0, 12, 24
            try
              kn = parseInt rec[k].trim()
              nv = kn if typeof kn is 'number' and not isNaN kn and kn isnt 0
              nr.embargo_end = '' if nv? # just to allow neat output later - can't be calculated until compared to a particular article
          else if k in ['journal', 'versionsarchivable', 'archivinglocationsallowed', 'licencesallowed', 'policyfulltext', 'contributedby', 'addedby', 'reviewers', 'iffundedby']
            nv = []
            for s in rcs = rec[k].trim().split ','
              st = s.trim()
              if k is 'licencesallowed'
                lc = type: st.toLowerCase()
                try lc.terms = rec.licenceterms.split(',')[rcs.indexOf(s)].trim() # these don't seem to exist any more...
                nv.push lc
              else
                if k is 'versionsarchivable'
                  st = st.toLowerCase()
                  st = 'submittedVersion' if st is 'preprint'
                  st = 'acceptedVersion' if st is 'postprint'
                  st = 'publishedVersion' if st is 'publisher pdf'
                nv.push(if k in ['archivinglocationsallowed'] then st.toLowerCase() else st) if st.length and st not in nv
          else if k not in ['recordlastupdated']
            nv = rec[k].trim()
          nv = nv.toLowerCase() if typeof nv is 'string' and (nv.toLowerCase() in ['yes','no'] or k in ['haspolicy','permissiontype','copyrightowner'])
          if nv?
            if nk.indexOf('.') isnt -1
              nps = nk.split '.'
              nr[nps[0]] ?= {}
              nr[nps[0]][[nps[1]]] = nv
            else
              nr[nk] = nv
  
      # Archived Full Text Link - a URL to a web archive link of the full text policy link (ever multiple?)
      # Record First Added - date like 12/07/2017
      # Post-publication Pre-print Update Allowed - string like No, Yes, could be empty (turn these to booleans?)
      # Can Authors Opt Out - seems to be all empty, could presumably be Yes or No
  
      nr.licences ?= []
      if not nr.licence
        for l in nr.licences
          if not nr.licence? or l.type.length < nr.licence.length
            nr.licence = l.type
            nr.licence_terms = l.terms
      nr.versions ?= []
      if nr.versions.length
        nr.can_archive = true
        nr.version = if 'acceptedVersion' in nr.versions or 'postprint' in nr.versions then 'acceptedVersion' else if 'publishedVersion' in nr.versions or 'publisher pdf' in nr.versions then 'publishedVersion' else 'submittedVersion'
      nr.copyright_owner ?= nr.issuer?.type ? ''
      nr.copyright_name ?= ''
      nr.copyright_year ?= '' # the year of publication, to be added at result stage
      ready.push(nr) if not _.isEmpty nr
      #console.log nr
      
      # TODO if there is a provenance.example DOI look up the metadata for it and find the journal ISSN. 
      # then have a search for ISSN be able to find that. Otherwise, we have coverage by publisher that 
      # contains no journal info, so no way to go from ISSN to the stored record

  if ready.length
    if reload
      # ideally want a unique ID per record so would only have to update the changed ones
      # but as that is not yet possible, have to just dump and reload all
      oab_permissions.remove '*'
      oab_permissions.insert ready
  API.mail.send
    service: 'openaccessbutton'
    from: 'requests@openaccessbutton.org'
    to: 'alert@cottagelabs.com'
    subject: 'OAB permissions import check complete'
    text: 'Found ' + records.length + ' in sheet, imported ' + ready.length + ' records'
  return ready.length

# run import every day on the main machine
_oab_permissions_import = () ->
  if API.settings.cluster?.ip? and API.status.ip() not in API.settings.cluster.ip
    API.log 'Setting up an OAB permissions import to run every day if not triggered by request on ' + API.status.ip()
    Meteor.setInterval (() -> API.service.oab.permission.import()), 86400000
Meteor.setTimeout _oab_permissions_import, 24000



API.service.oab.permission.file = (file, url, confirmed) ->
  f = {archivable: undefined, archivable_reason: undefined, version: 'unknown', same_paper: undefined, licence: undefined}

  # handle different sorts of file passing
  if typeof file is 'string'
    file = data: file
  if _.isArray file
    file = if file.length then file[0] else undefined
  if not file? and url?
    file = API.http.getFile url

  if file?
    file.name ?= file.filename
    try f.name = file.name
    try f.format = if file.name? and file.name.indexOf('.') isnt -1 then file.name.substr(file.name.lastIndexOf('.')+1) else 'html'
    if file.data
      if f.format is 'pdf'
        try content = API.convert.pdf2txt file.data
      if not content? and f.format? and API.convert[f.format+'2txt']?
        try content = API.convert[f.format+'2txt'] file.data
      if not content?
        content = API.convert.file2txt file.data, {name: file.name}
      if not content?
        fd = file.data
        if typeof file.data isnt 'string'
          try fd = file.data.toString()
        try
          if fd.indexOf('<html') is 0
            content = API.convert.html2txt fd
          else if file.data.indexOf('<xml') is 0
            content = API.convert.xml2txt fd
      try content ?= file.data
      try content = content.toString()

  if not content? and not confirmed
    if file? or url?
      f.error = file.error ? 'Could not extract any content'
  else
    _clean = (str) -> return str.toLowerCase().replace(/[^a-z0-9\/\.]+/g, "").replace(/\s\s+/g, ' ').trim()

    contentsmall = if content.length < 20000 then content else content.substring(0,6000) + content.substring(content.length-6000,content.length)
    lowercontentsmall = contentsmall.toLowerCase()
    lowercontentstart = _clean(if lowercontentsmall.length < 6000 then lowercontentsmall else lowercontentsmall.substring(0,6000))

    f.name ?= meta.title
    try f.checksum = crypto.createHash('md5').update(content, 'utf8').digest('base64')
    f.same_paper_evidence = {} # check if the file meets our expectations
    try f.same_paper_evidence.words_count = content.split(' ').length # will need to be at least 500 words
    try f.same_paper_evidence.words_more_than_threshold = if f.same_paper_evidence.words_count > 500 then true else false
    try f.same_paper_evidence.doi_match = if meta.doi and lowercontentstart.indexOf(_clean meta.doi) isnt -1 then true else false # should have the doi in it near the front
    if content and not f.same_paper_evidence.doi_match and not meta.title?
      meta = API.service.oab.metadata undefined, meta, content # get at least title again if not already tried to get it, and could not find doi in the file
    try f.same_paper_evidence.title_match = if meta.title and lowercontentstart.replace(/\./g,'').indexOf(_clean meta.title.replace(/ /g,'').replace(/\./g,'')) isnt -1 then true else false
    if meta.author?
      try
        authorsfound = 0
        f.same_paper_evidence.author_match = false
        # get the surnames out if possible, or author name strings, and find at least one in the doc if there are three or less, or find at least two otherwise
        meta.author = {name: meta.author} if typeof meta.author is 'string'
        meta.author = [meta.author] if not _.isArray meta.author
        for a in meta.author
          if f.same_paper_evidence.author_match is true
            break
          else
            try
              an = (a.last ? a.lastname ? a.family ? a.surname ? a.name).trim().split(',')[0].split(' ')[0]
              af = (a.first ? a.firstname ? a.given ? a.name).trim().split(',')[0].split(' ')[0]
              inc = lowercontentstart.indexOf _clean an
              if an.length > 2 and af.length > 0 and inc isnt -1 and lowercontentstart.substring(inc-20,inc+an.length+20).indexOf(_clean af) isnt -1
                authorsfound += 1
                if (meta.author.length < 3 and authorsfound is 1) or (meta.author.length > 2 and authorsfound > 1)
                  f.same_paper_evidence.author_match = true
                  break
    if f.format?
      for ft in ['doc','tex','pdf','htm','xml','txt','rtf','odf','odt','page']
        if f.format.indexOf(ft) isnt -1
          f.same_paper_evidence.document_format = true
          break

    f.same_paper = if f.same_paper_evidence.words_more_than_threshold and (f.same_paper_evidence.doi_match or f.same_paper_evidence.title_match or f.same_paper_evidence.author_match) and f.same_paper_evidence.document_format then true else false

    if f.same_paper_evidence.words_count is 1 and f.format is 'pdf'
      # there was likely a pdf file reading failure due to bad PDF formatting
      f.same_paper_evidence.words_count = 0
      f.archivable_reason = 'We could not find any text in the provided PDF. It is possible the PDF is a scan in which case text is only contained within images which we do not yet extract. Or, the PDF may have errors in it\'s structure which stops us being able to machine-read it'

    f.version_evidence = score: 0, strings_checked: 0, strings_matched: []
    try
      # dev https://docs.google.com/spreadsheets/d/1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg/edit#gid=0
      # live https://docs.google.com/spreadsheets/d/10DNDmOG19shNnuw6cwtCpK-sBnexRCCtD4WnxJx_DPQ/edit#gid=0
      for l in API.use.google.sheets.feed (if API.settings.dev then '1XA29lqVPCJ2FQ6siLywahxBTLFaDCZKaN5qUeoTuApg' else '10DNDmOG19shNnuw6cwtCpK-sBnexRCCtD4WnxJx_DPQ')
        try
          f.version_evidence.strings_checked += 1
          wts = l.whattosearch
          if wts.indexOf('<<') isnt -1 and wts.indexOf('>>') isnt -1
            wtm = wts.split('<<')[1].split('>>')[0]
            wts = wts.replace('<<'+wtm+'>>',meta[wtm.toLowerCase()]) if meta[wtm.toLowerCase()]?
          matched = false
          if l.howtosearch is 'string'
            #wtsc = _clean wts
            #matched = if (l.wheretosearch is 'file' and _clean(lowercontentsmall).indexOf(wtsc) isnt -1) or (l.wheretosearch isnt 'file' and ((meta.title? and _clean(meta.title).indexOf(wtsc) isnt -1) or (f.name? and _clean(f.name).indexOf(wtsc) isnt -1))) then true else false
            matched = if (l.wheretosearch is 'file' and contentsmall.indexOf(wts) isnt -1) or (l.wheretosearch isnt 'file' and ((meta.title? and meta.title.indexOf(wts) isnt -1) or (f.name? and f.name.indexOf(wts) isnt -1))) then true else false
          else
            # could change this to be explicit and not use lowercasing, if wanting more exactness
            re = new RegExp wts, 'gium'
            matched = if (l.wheretosearch is 'file' and lowercontentsmall.match(re) isnt null) or (l.wheretosearch isnt 'file' and ((meta.title? and meta.title.match(re) isnt null) or (f.name? and f.name.match(re) isnt null))) then true else false
          if matched
            sc = l.score ? l.score_value
            if typeof sc is 'string'
              try sc = parseInt sc
            sc = 1 if typeof sc isnt 'number'
            if l.whatitindicates is 'publisher pdf' then f.version_evidence.score += sc else f.version_evidence.score -= sc
            f.version_evidence.strings_matched.push {indicates: l.whatitindicates, found: l.howtosearch + ' ' + wts, in: l.wheretosearch, score_value: sc}

    f.version = 'publishedVersion' if f.version_evidence.score > 0
    f.version = 'acceptedVersion' if f.version_evidence.score < 0
    if f.version is 'unknown' and f.version_evidence.strings_checked > 0 #and f.format? and f.format isnt 'pdf'
      f.version = 'acceptedVersion'

    try
      ls = API.service.lantern.licence undefined, undefined, lowercontentsmall # check lantern for licence info in the file content
      if ls?.licence?
        f.licence = ls.licence
        f.licence_evidence = {string_match: ls.match}
      f.lantern = ls

    f.archivable = false
    if confirmed
      f.archivable = true
      if confirmed is f.checksum
        f.archivable_reason = 'The administrator has confirmed that this file is a version that can be archived.'
        f.admin_confirms = true
      else
        f.archivable_reason = 'The depositor says that this file is a version that can be archived'
        f.depositor_says = true
    else if f.same_paper
      if f.format isnt 'pdf'
        f.archivable = true
        f.archivable_reason = 'Since the file is not a PDF, we assume it is a Postprint.'
      if not f.archivable and f.licence? and f.licence.toLowerCase().indexOf('cc') is 0
        f.archivable = true
        f.archivable_reason = 'It appears this file contains a ' + f.lantern.licence + ' licence statement. Under this licence the article can be archived'
      if not f.archivable
        if f.version is 'publishedVersion'
          f.archivable_reason = 'The file given is a Publisher PDF, and only postprints are allowed'
        else
          f.archivable_reason = 'We cannot confirm if it is an archivable version or not'
    else
      f.archivable_reason ?= if not f.same_paper_evidence.words_more_than_threshold then 'The file is less than 500 words, and so does not appear to be a full article' else if not f.same_paper_evidence.document_format then 'File is an unexpected format ' + f.format else if not meta.doi and not meta.title then 'We have insufficient metadata to validate file is for the correct paper ' else 'File does not contain expected metadata such as DOI or title'

  return f



API.service.oab.permission.test = (email) ->
  res = {tests: 0, same: 0, results: {}}
  for test in ts = API.use.google.sheets.feed '1vuzkrvbd2U3stLBGXMIHE_mtZ5J3YUhyRZEf08mNtM8', 0
    break if res.tests > 2
    if test.doi and test.doi.startsWith('10.') and test.responseurl
      console.log res.tests
      res.tests += 1
      res.results[test.doi] = {}
      try
        perms = API.service.oab.permission(doi: test.doi.split('?')[0], ror: (if test.doi.indexOf('?') isnt -1 then test.doi.split('?')[1].split('=')[1] else undefined)).best_permission
      catch
        perms = {}
      try
        ricks = HTTP.call('GET', test.responseurl).data.authoritative_permission.application
      catch
        ricks = {}
      if perms? and ricks?
        diffs = {}
        for k in ['can_archive']
          if not perms[k]? or not ricks[k]? or perms[k] isnt ricks[k]
            diffs[k] = [perms[k],ricks[k]]
        if _.isEmpty diffs
          res.same += 1
          res.results[test.doi].same = true
        else
          res.results[test.doi].same = false
          res.results[test.doi].diffs = diffs
        res.results[test.doi].perms = perms
        res.results[test.doi].ricks = ricks

  API.mail.send
    service: 'openaccessbutton'
    from: 'requests@openaccessbutton.org'
    to: email ? 'alert@cottagelabs.com'
    subject: 'OAB permissions test complete'
    text: JSON.stringify res, '', 2
  return res