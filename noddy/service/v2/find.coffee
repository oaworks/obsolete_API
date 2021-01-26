
import Future from 'fibers/future'
import unidecode from 'unidecode'

API.service.oab.ftitle = (title) ->
  # a useful way to show a title (or other string) as one long string with no weird characters
  ft = ''
  for tp in unidecode(title.toLowerCase()).replace(/[^a-z0-9 ]/g,'').replace(/ +/g,' ').split(' ')
    ft += tp
  return ft

API.service.oab.finder = (metadata) ->
  if metadata.citation?
    for k of c = API.service.oab.citation metadata.citation
      metadata[k] = c[k]
  finder = ''
  for tid in ['doi','pmid','pmcid','url','title']
    if typeof metadata[tid] is 'string' or typeof metadata[tid] is 'number' or _.isArray metadata[tid]
      mt = if _.isArray metadata[tid] then metadata[tid][0] else metadata[tid]
      if typeof mt is 'number' or (typeof mt is 'string' and mt.length > 5) # people pass n/a and such into title, so ignore anything too small to be a title or a valid id
        finder += ' OR ' if finder isnt ''
        if tid is 'title'
          finder += 'ftitle:' + API.service.oab.ftitle(mt) + ' OR '
        if tid is 'doi'
          finder += 'doi_not_in_crossref.exact:"' + mt + '" OR '
        finder += 'metadata.' + tid + (if tid is 'url' or tid is 'title' then '' else '.exact') + ':"' + mt + '"'
  return finder

oab_catalogue.finder = (metadata) ->
  finder = if typeof metadata is 'string' then metadata else API.service.oab.finder metadata
  return if finder isnt '' then oab_catalogue.find(finder, true) else undefined

_find =
  authOptional: true
  action: () ->
    opts = if not _.isEmpty(this.request.body) then this.request.body else this.queryParams
    opts[p] ?= this.queryParams[p] for p of this.queryParams
    if this.user?
      opts.uid = this.userId
      opts.username = this.user.username
      opts.email = this.user.emails[0].address
    opts.url = opts.url[0] if _.isArray opts.url
    if not opts.test and opts.url and API.service.oab.blacklist(opts.url) is true
      opts.dom = 'redacted' if opts.dom
      API.log 'find request blacklisted for ' + JSON.stringify opts
      return 400
    else
      return API.service.oab.find opts
API.add 'service/oab/find', get:_find, post:_find

API.add 'service/oab/finds', () -> return oab_find.search this, {exclude: ['config']}
API.add 'service/oab/found', () -> return oab_catalogue.search this, {restrict:[{exists: {field:'url'}}], exclude: ['config']}

API.add 'service/oab/catalogue', () -> return oab_catalogue.search this
API.add 'service/oab/catalogue/keys', get: () -> return oab_catalogue.keys()
API.add 'service/oab/catalogue/finder', 
  get: () ->
    res = query: API.service.oab.finder this.queryParams
    res.count = oab_catalogue.count res.query
    res.find = oab_catalogue.finder res.query
    return res
API.add 'service/oab/catalogue/history', () -> return oab_catalogue.history this
API.add 'service/oab/catalogue/:cid', get: () -> return oab_catalogue.get this.urlParams.cid

API.add 'service/oab/metadata',
  get: () -> return API.service.oab.metadata this.queryParams
  post: () -> return API.service.oab.metadata this.request.body
API.add 'service/oab/metadata/keys',
  get: () -> 
    keys = []
    for k in oab_catalogue.keys()
      keys.push(k.replace('metadata.','')) if k.indexOf('metadata') is 0 and k isnt 'metadata'
    return keys

API.add 'service/oab/citation', get: () -> return API.service.oab.citation this.queryParams.citation ? this.queryParams.cite ? this.queryParams.q


# exists for legacy reasons, _avail should be altered to make sure the _find returns what /availability used to
_avail =
  authOptional: true
  action: () ->
    opts = if not _.isEmpty(this.request.body) then this.request.body else this.queryParams
    opts[p] ?= this.queryParams[p] for p of this.queryParams
    if this.user?
      opts.uid = this.userId
      opts.username = this.user.username
      opts.email = this.user.emails[0].address
    opts.url = opts.url[0] if _.isArray opts.url
    if not opts.test and opts.url and API.service.oab.blacklist(opts.url) is true
      opts.dom = 'redacted' if opts.dom
      API.log 'find request blacklisted for ' + JSON.stringify opts
      return 400
    else
      return API.service.oab.availability opts
API.add 'service/oab/availability', get:_avail, post:_avail
API.add 'service/oab/availabilities', () -> return oab_find.search this

API.service.oab.availability = (opts,v2) ->
  afnd = {data: {availability: [], requests: [], accepts: [], meta: {article: {}, data: {}}}}
  if opts?
    afnd.data.match = opts.doi ? opts.pmid ? opts.pmc ? opts.pmcid ? opts.title ? opts.url ? opts.id ? opts.citation ? opts.q
  afnd.v2 = if typeof v2 is 'object' and not _.isEmpty(v2) and v2.metadata? then v2 else if opts? then API.service.oab.find(opts) else undefined
  if afnd.v2?
    afnd.data.match ?= afnd.v2.input ? afnd.v2.metadata?.doi ? afnd.v2.metadata?.title ? afnd.v2.metadata?.pmid ? afnd.v2.metadata?.pmc ? afnd.v2.metadata?.pmcid ? afnd.v2.metadata?.url
    afnd.data.match = afnd.data.match[0] if _.isArray afnd.data.match
    try
      afnd.data.ill = afnd.v2.ill
      afnd.data.meta.article = JSON.parse(JSON.stringify(afnd.v2.metadata)) if afnd.v2.metadata?
      afnd.data.meta.cache = afnd.v2.cached
      afnd.data.meta.refresh = afnd.v2.refresh
      afnd.data.meta.article.url = afnd.data.meta.article.url[0] if _.isArray afnd.data.meta.article.url
      if afnd.v2.url? and afnd.v2.found? and not afnd.data.meta.article.source?
        for vf of afnd.v2.found
          if vf isnt 'oabutton' and afnd.v2.found[vf] is afnd.v2.url
            afnd.data.meta.article.source = vf
            break
      afnd.data.meta.article.bing = true if 'bing' in afnd.v2.checked
      if afnd.v2.url
        afnd.data.availability.push({type: 'article', url: (if _.isArray(afnd.v2.url) then afnd.v2.url[0] else afnd.v2.url)})
    try
      if afnd.data.availability.length is 0 and (afnd.v2.metadata.doi or afnd.v2.metadata.title or (afnd.v2.metadata.url and afnd.v2.meadata.url.length))
        eq = {type: 'article'}
        if afnd.v2.metadata.doi
          eq.doi = afnd.v2.metadata.doi
        else if afnd.v2.metadata.title
          eq.title = afnd.v2.metadata.title
        else
          eq.url = afnd.v2.metadata.url
          eq.url = eq.url[0] if _.isArray eq.url
        if request = oab_request.find eq
          rq = type: 'article', _id: request._id
          rq.ucreated = if opts.uid and request.user?.id is opts.uid then true else false
          rq.usupport = if opts.uid then API.service.oab.supports(request._id, opts.uid)? else false
          afnd.data.requests.push rq
  afnd.data.accepts.push({type:'article'}) if afnd.data.availability.length is 0 and afnd.data.requests.length is 0
  return afnd



API.service.oab.metadata = (options={}, metadata, content) -> # pass-through to find that ensures the settings will get metadata rather than fail fast on find
  if typeof options is 'string'
    options = if options.indexOf('10.') is 0 then {doi: options} else if options.indexOf('http') is 0 then {url: options} else {title: options}
  options.metadata ?= true
  #options.refresh ?= true
  options.find = false
  return API.service.oab.find(options, metadata, content).metadata

API.service.oab.find = (options={}, metadata={}, content) ->
  started = Date.now()
  res = {url: false, input: '', checked: []}

  # clean user inputs for bad characters
  options = API.tdm.clean options
  metadata = API.tdm.clean metadata
  
  # libraries want to know the input that was searched, it could be one of various 
  # params depending on the source so stringify it and store it just in case
  for o in ['doi','title','id','pmid','pmcid','pmc','url','citation','q']
    res.input += (if res.input.length then ', ' else '') + o + ': "' + options[o] + '"' if options[o]
    
  
  # metadata cleaner ===========================================================
  _get = {}
  _get.metadata = (input) ->
    info = JSON.parse JSON.stringify input # so it does not get wiped during loops
    if typeof info is 'object' and not _.isEmpty info
      info.licence ?= info.best_oa_location?.license ? info.license
      info.issn ?= info.journalInfo?.journal?.issn ? info.journal?.issn
      # get what we need out of whatever is returned, in a tidy way
      # we can get a 404 for an article behind a loginwall if the service does not do splash pages,
      # and then we can accidentally get the article that exists called "404 not found". So we just don't
      # run checks for titles that start with 404 - see https://github.com/OAButton/discussion/issues/931
      # this is the article: http://research.sabanciuniv.edu/34037/    info.lice
      info.title ?= info.dctitle ? info.bibjson?.title ? info.metadata?['oaf:result']?.title?.$
      if not metadata.title and info.title?
        delete info.title if (info.title is 404 or info.title.indexOf('404') is 0)
        info.title = info.title.replace(/\s\s+/g,' ').trim() if typeof info.title is 'string'
      info.journal ?= info.journalInfo?.journal?.title ? info.journal?.title
      if not metadata.journal and info.journal?
        info.journal = info.journal.split('(')[0].trim()
      for key in ['title','journal'] # tidy title and journal to start with uppercase, and not be all lowercase or all uppercase
        if not metadata[key] and typeof info[key] is 'string' and (info[key].charAt(0).toUpperCase() isnt info[key].charAt(0) or info[key].toUpperCase() is info.key or info[key].toLowerCase() is info.key)
          try info[key] = info[key].charAt(0).toUpperCase() + info[key].slice(1)
      # fix possibly messy years
      if not metadata.year? and info.year?
        try
          for ms in info.year.split('/')
            info.year = ms if ms.length is 4
        try
          for md in info.year.split('-')
            info.year = md if md.length is 4
        try
          delete info.year if typeof info.year isnt 'number' and (info.year.length isnt 4 or info.year.replace(/[0-9]/gi,'').length isnt 0)
        if not info.year? and info.published?
          try
            mps = info.published.split('-')
            info.year = mps[0] if mps[0].length is 4
        try
          delete info.year if typeof info.year isnt 'number' and (info.year.length isnt 4 or info.year.replace(/[0-9]/gi,'').length isnt 0)
        catch
          if info.year?
            delete info.year
        info.year = info.year.toString() if typeof info.year is 'number'
      # remove authors if only present as strings (end users may provide them this way which causes problems in saving and re-using them
      # and author strings are not much use for discovering articles anyway
      if not metadata.author? and info.author?
        delete info.author if typeof info.author is 'string'
        delete info.author if _.isArray(info.author) and info.author.length > 0 and typeof info.author[0] is 'string'
      for i of info
        metadata[i] ?= info[i] if i not in ['ror'] and (typeof info[i] is 'string' or _.isArray info[i]) # not expecting objects back here by this point


  # prepare all the incoming metadata and options for use ======================
  if typeof options is 'string'
    metadata = options
    options = {}
  options = {} if typeof options isnt 'object'
  if typeof metadata is 'string'
    options.url = metadata
    metadata = {}
  else if typeof metadata isnt 'object'
    metadata = {}
  else if _.isEmpty(metadata) and typeof options.metadata is 'object' and not _.isArray options.metadata
    metadata = options.metadata
    options.metadata = true
  options.metadata = if options.metadata is true then ['title','doi','author','journal','issn','volume','issue','page','published','publisher','year'] else if _.isArray(options.metadata) then options.metadata else []
  content ?= options.dom if options.dom?

  if metadata.url
    options.url ?= metadata.url
    delete metadata.url
  if metadata.id
    options.id = metadata.id
    delete metadata.id
  options.url = options.url[0] if _.isArray options.url

  metadata.doi ?= options.doi.replace('doi:','').replace('doi.org/','').trim() if typeof options.doi is 'string'
  if typeof options.title is 'string'
    options.title = options.title.replace(/\+/g,' ').trim()
    metadata.title ?= options.title
  metadata.pmid ?= options.pmid if options.pmid
  metadata.pmcid ?= options.pmcid if options.pmcid
  metadata.pmcid ?= options.pmc if options.pmc
  if options.q
    options.url = options.q
    delete options.q
  if options.id
    options.url = options.id
    delete options.id
  if options.url
    options.url = options.url.toString() if typeof options.url is 'number'
    if options.url.indexOf('/10.') isnt -1
      # we don't use a regex to try to pattern match a DOI because people often make mistakes typing them, so instead try to find one
      # in ways that may still match even with different expressions (as long as the DOI portion itself is still correct after extraction we can match it)
      dd = '10.' + options.url.split('/10.')[1].split('&')[0].split('#')[0]
      if dd.indexOf('/') isnt -1 and dd.split('/')[0].length > 6 and dd.length > 8
        dps = dd.split('/')
        dd = dps.join('/') if dps.length > 2
        metadata.doi ?= dd
    if options.url.replace('doi:','').replace('doi.org/','').trim().indexOf('10.') is 0
      metadata.doi ?= options.url.replace('doi:','').replace('doi.org/','').trim()
      options.url = 'https://doi.org/' + metadata.doi
    else if options.url.toLowerCase().indexOf('pmc') is 0
      metadata.pmcid ?= options.url.toLowerCase().replace('pmcid','').replace('pmc','')
      options.url = 'http://europepmc.org/articles/PMC' + metadata.pmcid
    else if options.url.replace(/pmid/i,'').replace(':','').length < 10 and options.url.indexOf('.') is -1 and not isNaN(parseInt(options.url.replace(/pmid/i,'').replace(':','').trim()))
      metadata.pmid ?= options.url.replace(/pmid/i,'').replace(':','').trim()
      options.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + metadata.pmid
    else if not metadata.title? and options.url.indexOf('http') isnt 0
      if options.url.indexOf('{') isnt -1 or (options.url.replace('...','').match(/\./gi) ? []).length > 3 or (options.url.match(/\(/gi) ? []).length > 2
        options.citation = options.url
      else
        metadata.title = options.url
    delete options.url if options.url.indexOf('http') isnt 0 or options.url.indexOf('.') is -1
  if options.title and (options.title.indexOf('http') isnt -1 or options.title.indexOf('{') isnt -1 or (options.title.replace('...','').match(/\./gi) ? []).length > 3 or (options.title.match(/\(/gi) ? []).length > 2)
    options.citation = options.title # titles that look like citations
    delete options.title
  if (options.citation or options.title) and not options.doi and (options.citation ? options.title).indexOf('10.') isnt -1
    ts = (options.citation ? options.title).split('10.')[1].split(' ')[0]
    if ts.indexOf('/') isnt -1 and ts.length > 6
      options.doi = '10.' + ts
      metadata.doi = options.doi
      delete metadata.title
      delete metadata.citation
  if options.citation? or options.title?
    try
      cmt = API.service.oab.citation options.citation ? options.title
      metadata[c] = cmt[c] for c of cmt
  metadata.title = metadata.title.replace(/(<([^>]+)>)/g,'').replace(/\+/g,' ').trim() if typeof metadata.title is 'string'
  delete metadata.doi if typeof metadata.doi isnt 'string' or metadata.doi.indexOf('10.') isnt 0
  if typeof metadata.doi is 'string' # gets rid of some junk passed in after doi in some cases
    metadata.doi = metadata.doi.split(' ')[0]
    metadata.doi = metadata.doi.replace('doi.org/','').trim() if metadata.doi.indexOf('doi.org/') is 0
    metadata.doi = metadata.doi.replace('doi:','').trim() if metadata.doi.indexOf('doi:') is 0

  options.permissions ?= options.plugin is 'shareyourpaper' # don't get permissions by default now that the permissions check could take longer
  options.ill ?= (options.from? or options.config?) and options.plugin is 'instantill' # get ILL info too if necessary
  options.bing ?= API.settings?.service?.openaccessbutton?.resolve?.bing is true
  options.bing = false if API.settings?.service?.openaccessbutton?.resolve?.bing is false
  # switch exlibris URLs for titles, which the scraper knows how to extract, because the exlibris url would always be the same
  if not metadata.title and content and typeof options.url is 'string' and (options.url.indexOf('alma.exlibrisgroup.com') isnt -1 or options.url.indexOf('/exlibristest') isnt -1)
    delete options.url
    res.exlibris = true

  res.plugin = options.plugin if options.plugin?
  res.from = options.from if options.from?
  res.find = options.find ? true
  # other possible sources are ['base','dissemin','share','core','openaire','bing','fighsare']
  res.sources = options.sources ? ['oabutton','catalogue','oadoi','crossref','epmc','scrape'] # 'mag'
  res.sources.push('bing') if options.bing and options.plugin is 'instantill' # (options.plugin in ['widget','oasheet','instantill'] or options.from in ['illiad','clio'] or res.exlibris)
  options.refresh = if options.refresh is 'true' or options.refresh is true then true else if options.refresh is 'false' or options.refesh is false then false else options.refresh
  try res.refresh = if options.refresh is false then 30 else if options.refresh is true then 0 else parseInt options.refresh
  res.refresh = 30 if typeof res.refresh isnt 'number' or isNaN res.refresh
  res.embedded ?= options.embedded if options.embedded?
  res.pilot = options.pilot if options.pilot? # instantill and shareyourpaper can state if they are live or pilot, and if wrong item supplied
  if typeof res.pilot is 'boolean' # catch possible old erros with live/pilot values
    res.pilot = if res.pilot is true then Date.now() else undefined
  res.live = options.live if options.live?
  if typeof res.live is 'boolean'
    res.live = if res.live is true then Date.now() else undefined
  res.wrong = options.wrong if options.wrong?
  res.found = {}
  
  catalogued = undefined # if we find the article already in our catalogue, use this to track and update it

  groups = ['oab']
  groups.push(res.plugin) if options.plugin
  groups.push(options.from) if options.from in ['illiad','clio']
  API.log msg: 'OAB finding academic content', group: groups, level: 'debug', metadata: JSON.stringify metadata

  # prep complete ==============================================================


  # set a demo tag in certain cases ====================================
  # e.g. for instantill/shareyourpaper/other demos - dev and live demo accounts
  res.demo = options.demo
  res.demo ?= true if (metadata.doi is '10.1234/567890' or (metadata.doi? and metadata.doi.indexOf('10.1234/oab-syp-') is 0)) or metadata.title is 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL' or options.from in ['qZooaHWRz9NLFNcgR','eZwJ83xp3oZDaec86']
  res.test ?= true if res.demo # don't save things coming from the demo accounts into the catalogue later

  # sub-processes to loop call until all result parts are found ================
  done = {}
  used = []

  _got = (obj=metadata) ->
    # check if we have everything we need yet
    for w in options.metadata
      if not obj[w]?
        return false
    return true

  _get.oabutton = () ->
    catalogued = oab_catalogue.finder metadata
    if _.isArray catalogued?.found?.epmc? # can remove these fixes if catalogue is dropped
      delete catalogued.found.epmc 
      delete catalogued.url if _.isArray catalogued.url
      delete catalogued.metadata.url if _.isArray catalogued.metadata?.url
    # if user wants a total refresh, don't use any of it (we still search for it though, because will overwrite later with the fresh stuff)
    if catalogued? and res.refresh isnt 0
      # decided to disable using cached permissions, calculating them is fast now anyway. To re-enable, would have to take account of RORs etc
      #res.permissions ?= catalogued.permissions if catalogued.permissions?.best_permission? and not _.isEmpty(catalogued.permissions.best_permission) and (catalogued.metadata?.journal? or catalogued.metadata?.issn?)
      if 'oabutton' in res.sources
        delete catalogued.metadata.issn if typeof catalogued.metadata?.issn is 'string'
        delete catalogued.metadata.ror if catalogued.metadata?.ror? # because of old wrong RORs
        if catalogued.url? # within or without refresh time, if we have already found it, re-use it
          _get.metadata catalogued.metadata
          res.cached = true
          res.found = catalogued.found
          res.url = catalogued.url
          res.url = res.url[0] if _.isArray res.url
        else if (catalogued.updatedAt ? catalogued.createdAt) > Date.now() - res.refresh*86400000
          _get.metadata catalogued.metadata # it is in the catalogue but we don't have a link for it, and it is within refresh days old, so re-use the metadata from it
          res.cached = true

  _get.catalogue = () ->
    if inc = API.service.academic.article.doi metadata.doi
      delete inc.ror # because of old wrong RORs
      _get.metadata inc
    
  _get.mag = () ->
    mgr = false
    if metadata.doi
      try mgr = API.use.microsoft.graph.paper.doi metadata.doi
    if typeof mgr isnt 'object' and metadata.title
      try mgr = API.use.microsoft.graph.paper.title metadata.title
    if typeof mgr is 'object'
      metadata.doi ?= mgr.Doi if mgr.Doi
      metadata.title ?= mgr.PaperTitle if mgr.PaperTitle
      metadata.year ?= mgr.Year if mgr.Year
      metadata.publisher ?= mgr.Publisher if mgr.Publisher
      metadata.volume ?= mgr.Volume if mgr.Volume
      metadata.issue ?= mgr.Issue if mgr.Issue
      if mgr.FirstPage or mgr.LastPage and not metadata.pages
        metadata.pages = mgr.FirstPage ? ''
        if mgr.LastPage
          metadata.pages += (if metadata.pages.length then ' - ' else '') + mgr.LastPage
      metadata.journal ?= mgr.journal.DisplayName if mgr.journal?.DisplayName
      metadata.issn ?= mgr.journal.Issn.split(',') if mgr.journal?.Issn # I think these are always single strings, but a split makes them a list even if there is only ever one anyway.
      metadata.published ?= mgr.Date if mgr.Date
      metadata.abstract = mgr.abstract if mgr.abstract
      metadata.author ?= []
      hasauthors = metadata.author.length
      if mgr.relation? and mgr.relation.length
        for rl in mgr.relation
          if rl.AuthorId
            at = name: rl.DisplayName ? rl.OriginalAuthor
            at.institution = rl.OriginalAffiliation if rl.OriginalAffiliation
            at.institution ?= rl.affiliation.DisplayName if rl.affiliation?.DisplayName
            at.ror = rl.ror if rl.ror
            at.ror = rl.affiliation.ror if rl.affiliation?.ror
            if not hasauthors
              metadata.author.push at
            if at.ror # could try merging authors with possible crossref author data for example...
              metadata.ror ?= [] # but for now just get the rors
              metadata.ror.push(at.ror) if at.ror not in metadata.ror
  
  _get.bing = () ->
    mct = unidecode(metadata.title.toLowerCase()).replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ')
    bong = API.use.microsoft.bing.search mct, true, 2592000000, API.settings.use.microsoft.bing.key # search bing for what we think is a title (caching up to 30 days)
    if bong?.data? and bong.data.length
      bct = unidecode(bong.data[0].name.toLowerCase()).replace('(pdf)','').replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ')
      if not API.service.oab.blacklist(bong.data[0].url) and mct.replace(/ /g,'').indexOf(bct.replace(/ /g,'')) is 0 # if the URL is usable and tidy bing title is not a partial match to the start of the provided title, we won't do anything with it
        try
          if bong.data[0].name.indexOf('PDF') is -1 and (bong.data[0].url.toLowerCase().indexOf('.pdf') is -1 or mct.replace(/[^a-z0-9]+/g, "").indexOf(bong.data[0].url.toLowerCase().split('.pdf')[0].split('/').pop().replace(/[^a-z0-9]+/g, "")) is 0)
            options.url = bong.data[0].url.replace(/"/g,'')
          else
            content = API.convert.pdf2txt(bong.data[0].url)
            content = content.substring(0,1000) if content.length > 1000
            content = content.toLowerCase().replace(/[^a-z0-9]/g,"").replace(/\s\s+/g, '')
            if content.indexOf(mct.replace(/ /g, '')) isnt -1
              options.url = bong.data[0].url.replace(/"/g,'')
              try
                _get.content()
                done.content = true
              res.url = options.url # is it safe to use these as open URLs?
        catch
          options.url = bong.data[0].url.replace(/"/g,'')
        metadata.pmid = options.url.replace(/\/$/,'').split('/').pop() if typeof options.url is 'string' and options.url.indexOf('pubmed.ncbi') isnt -1
        metadata.doi ?= '10.' + options.url.split('/10.')[1] if typeof options.url is 'string' and options.url.indexOf('/10.') isnt -1

  _get.content = () ->
    _get.metadata API.service.oab.scrape undefined, content 

  _get.scrape = () ->
    _get.metadata API.service.oab.scrape options.url

  _get.permissions = () ->
    res.permissions ?= API.service.oab.permission metadata, undefined, undefined, undefined, (options.config ? options.from)

  _get.ill = () ->
    res.ill ?= {} # terms and openurl can be done client-side by new embed but old embed can't so keep these a while longer
    try res.ill.terms = options.config?.terms ? API.service.oab.ill.terms options.from
    try res.ill.openurl = API.service.oab.ill.openurl (options.config ? options.from), metadata
    try res.ill.subscription = API.service.oab.ill.subscription (options.config ? options.from), metadata, res.refresh


  # loop runner ================================================================
  times = []
  _running = {}
  _run = (src, which='') ->
    runs = Date.now()
    if typeof _get[src] is 'function'
      _get[src]()
    else if not _got() or (res.find and not res.url) # check again due to any delay in loops
      try
        rs = false
        if src is 'oadoi'
          if which is 'doi' and metadata.doi?
            rs = API.use.oadoi.doi metadata.doi, true
        else if src is 'crossref'
          if which in ['doi','title']
            # crossref title lookup can accept full metadata object to compare additional metadata possibly in a citation
            if which is 'title'
              if options.citation?
                mq = JSON.parse JSON.stringify metadata
                mq.citation = options.citation
              else
                mq = metadata.title
            else
              mq = metadata.doi
            rs = API.use.crossref.works[which] mq, true
            if which is 'doi' and not rs?.crossref_type
              res.doi_not_in_crossref = metadata.doi
              delete options.url if typeof options.url is 'string' and options.url.indexOf('doi.org/' + metadata.doi) isnt -1
              delete metadata.doi
              delete options.doi
        else if src is 'epmc'
          if which isnt 'doi' # don't bother with epmc lookup on DOI, as it will come back faster from other sources
            rs = API.use.europepmc[if which is 'id' then (if metadata.pmcid then 'pmc' else 'pmid') else which] (if which is 'id' then (metadata.pmcid ? metadata.pmid) else metadata[which]), true
        else if typeof API.use[src]?[which] is 'function' and metadata[which]?
          # other possible sources to check title or doi are ['base','dissemin','share','core','openaire','fighsare'] 
          # but we do not use them by default any more
          rs = API.use[src][which] metadata[which]
        if typeof rs is 'object'
          mt = rs.title ? rs.dctitle ? rs.bibjson?.title ? rs.metadata?['oaf:result']?.title?.$
          acceptable = which isnt 'title'
          if not acceptable and mt
            if not acceptable = mt.length > metadata.title.length and metadata.title.split(' ').length > 5 and mt.toLowerCase().replace(/[^a-z0-9]/g,'').indexOf(metadata.title.toLowerCase().replace(/[^a-z0-9]/g,'')) is 0
              if not acceptable = mt.length <= metadata.title.length*1.2 and mt.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(mt.toLowerCase().replace(' ','').replace(' ','').split(' ')[0]) is 0
                lvs = API.tdm.levenshtein mt, metadata.title, true
                longest = if lvs.length.a > lvs.length.b then lvs.length.a else lvs.length.b
                acceptable = lvs.distance < 2 or longest/lvs.distance > 10
          if acceptable
            _get.metadata rs
            if (rs.url or rs.redirect) and (src isnt 'crossref' or (typeof rs.licence is 'string' and rs.licence.indexOf('creativecommons') isnt -1)) 
              res.redirect = if rs.redirect then rs.redirect else rs.url
              res.url = res.redirect
              res.found[src] ?= res.url
    res.checked.push(src) if src not in res.checked
    rune = Date.now()
    times.push {src: src, which: which, started: runs, ended: rune, took: rune-runs}
    delete _running[src+which]

  _prl = (src, which='') -> 
    if not _running[src+which]
      _running[src+which] = true
      Meteor.setTimeout (() -> _run src, which), 1
  _loop = () ->
    dd = JSON.parse JSON.stringify done
    md = JSON.parse JSON.stringify metadata

    if not catalogued?
      ul = used.length
      more = false
      for tid in ['doi','title','pmid','pmcid','url']
        if metadata[tid] and tid not in used
          more = tid
          used.push tid
      if more
        if ul then _prl('oabutton') else _run('oabutton') # everything else waits for one check of the catalogue
        done['oabutton'+more] = true

    if not res.cached or (options.metadata.length and not _got()) or (not res.cached and res.find and not res.url)
      if metadata.doi and not done.dois
        done.dois = true
        for src in res.sources
          _prl(src, 'doi') if src not in ['oabutton','scrape','bing','mag']
      else if (metadata.pmcid or metadata.pmid) and not done.epmcid
        done.epmcid = true
        _prl('epmc','id')
      else if not done.mag and typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and 'mag' in res.sources
        done.mag = true
        _prl 'mag'
      else if _.isEmpty(_running) and not metadata.doi #or done.dois)
        if typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and not done.titles
          done.titles = true
          for src in res.sources
            _prl(src, 'title') if src not in ['oadoi','oabutton','catalogue','scrape','bing','mag']
        else if (not metadata.pmcid and not metadata.pmid) or done.epmcid
          if not metadata.title or (done.titles and (done.mag or 'mag' not in res.sources) and (done.bing or not options.bing or 'bing' not in res.sources))
            if not done.content and content
              done.content = true
              _run 'content'
            else if options.url and not done.scrape and 'scrape' in res.sources
              done.scrape = true
              _run 'scrape'
          else if not done.bing and not options.url and (done.mag or 'mag' not in res.sources) and typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and options.bing and 'bing' in res.sources
            done.bing = true
            _run 'bing'

    if metadata.doi and options.permissions and not done.permissions
      done.permissions = true
      _prl 'permissions'

    if metadata.doi
      for rn of _running
        delete _running[rn] if rn.indexOf('title') isnt -1 # don't wait for running title lookups if doi found since they started
    
    #console.log _running
    if (not _got() or (options.permissions and not res.permissions?) or (res.find and not res.url)) and (not _.isEmpty(_running) or not _.isEqual(dd, done) or not _.isEqual(md, metadata))
      future = new Future()
      Meteor.setTimeout (() -> future.return()), 50
      future.wait()
      _loop()
  _loop()
  
  _run('mag') if 'mag' in res.sources and not done.mag and (not res.cached or not _got())
  
  _get.oabutton() if not catalogued? # final check for a previous catalogue entry, with everything we know so far

  if options.ill and (metadata.doi or metadata.title) and not done.ill
    done.ill = true # have to do this after loop so that all metaadata is available for subscription lookup
    _run 'ill' # otherwise could put into loop above and call with _prl 'ill'

  # processing done, save and return ===========================================
  
  # update or create a catalogue record, and a find record, without waiting
  _save = (id, data, fnd) ->
    try
      # avoid a template clash between dev and live on find, temporary until decide what to do with find data long term
      delete fnd.metadata.subject 
    if data? and not _.isEmpty data
      try
        delete data.metadata.subject 
      if id
        oab_catalogue.update id, data
      else
        fnd.catalogue = oab_catalogue.insert data
    #fndc = JSON.parse JSON.stringify fnd
    #delete fnd.permissions # don't store permissions in finds, only in catalogue - not storing them at all now
    oab_find.insert fnd
  _sv = (id, data, fnd) -> Meteor.setTimeout (() -> _save(id, data, fnd)), 1

  # certain user-provided search values are allowed to override any that we could find ourselves, and we note that we got these from the user
  if options.usermetadata
    for uo in ['title','journal','year','doi']
      if not options.citation and options[uo] and options[uo].length and options[uo] isnt metadata[uo]
        if not (uo in ['title','year'] and not (options[if uo is 'title' then 'year' else 'title'] or options.journal or options.doi)) # but only accept title if given something else
          res.usermetadata ?= catalogued?.usermetadata ? {}
          res.usermetadata[uo] ?= []
          res.usermetadata[uo].push {previous: metadata[uo], provided: options[uo], uid: options.uid, createdAt: Date.now()}
          metadata[uo] = options[uo]

  metadata.url ?= []
  metadata.url = [metadata.url] if typeof metadata.url is 'string'
  if catalogued?.metadata?.url? and res.refresh isnt 0 and 'oabutton' in res.sources
    for cu in (if typeof catalogued.metadata.url is 'string' then [catalogued.metadata.url] else catalogued.metadata.url)
      metadata.url.push(cu) if cu not in metadata.url
  metadata.url.push(options.url) if typeof options.url is 'string' and options.url not in metadata.url and (options.url.indexOf('doi.org/') is -1 or options.url.indexOf(' ') is -1)
  metadata.url.push(res.url) if typeof res.url is 'string' and res.url not in metadata.url and (res.url.indexOf('doi.org/') is -1 or res.url.indexOf(' ') is -1)
  delete metadata.url if _.isEmpty metadata.url
  res.metadata = metadata

  delete res.url if res.url is false # we put url to the top of the response for humans using false, but remove that before saving
  res.uid = options.uid if options.uid
  res.username = options.username if options.username
  res.email = options.email if options.email
  try
    res.config = JSON.stringify(options.config) if options.config?
  res.times = times
  res.started = started
  res.ended = Date.now()
  res.took = res.ended - res.started

  if not _.isEmpty(metadata) and res.test isnt true
    res.url = res.url[0] if _.isArray res.url
    if catalogued?
      upd = {}
      upd.url = res.url if res.url? and res.url isnt catalogued.url
      if not _.isEqual metadata, catalogued.metadata
        upd.metadata = JSON.parse JSON.stringify metadata
        for m of catalogued.metadata
          upd.metadata[m] ?= catalogued.metadata[m]
        for cu in (if typeof catalogued.metadata?.url is 'string' then [catalogued.metadata.url] else if _.isArray(catalogued.metadata?.url) then catalogued.metadata.url else [])
          upd.metadata.url.push(cu) if cu not in upd.metadata.url
      upd.sources = _.union(res.sources, catalogued.sources) if JSON.stringify(res.sources.sort()) isnt JSON.stringify catalogued.sources.sort()
      uc = _.union res.checked, catalogued.checked
      upd.checked = uc if JSON.stringify(uc.sort()) isnt JSON.stringify catalogued.checked.sort()
      if not _.isEmpty res.found
        upd.found = JSON.parse JSON.stringify res.found
        for cf of catalogued.found
          upd.found[cf] ?= catalogued.found[cf]
      # not saving permissions any more
      #upd.permissions = res.permissions if res.permissions?.best_permission? and not _.isEmpty(res.permissions.best_permission) and (not catalogued.permissions? or not _.isEqual res.permissions, catalogued.permissions)
      upd.usermetadata = res.usermetadata if res.usermetadata?
      if typeof metadata.title is 'string'
        ftm = API.service.oab.ftitle(metadata.title)
        upd.ftitle = ftm if ftm isnt catalogued.ftitle
      res.catalogue = catalogued._id
      _sv catalogued._id, upd, res
    else
      fl = 
        url: res.url
        metadata: metadata
        sources: res.sources
        checked: res.checked
        found: res.found
        #permissions: res.permissions if res.permissions?.best_permission? and not _.isEmpty res.permissions.best_permission
      fl.ftitle = API.service.oab.ftitle(metadata.title) if typeof metadata.title is 'string'
      fl.usermetadata = res.usermetadata if res.usermetadata?
      _sv undefined, fl, res
  else
    _sv undefined, undefined, res

  return res



#Yi-Jeng Chen. (2016). Young Children's Collaboration on the Computer with Friends and Acquaintances. Journal of Educational Technology & Society, 19(1), 158-170. Retrieved November 19, 2020, from http://www.jstor.org/stable/jeductechsoci.19.1.158
#Baker, T. S., Eisenberg, D., & Eiserling, F. (1977). Ribulose Bisphosphate Carboxylase: A Two-Layered, Square-Shaped Molecule of Symmetry 422. Science, 196(4287), 293-295. doi:10.1126/science.196.4287.293
API.service.oab.citation = (citation) ->
  rs = if typeof citation is 'object' then citation else {}
  if typeof citation is 'string'
    try
      rs = JSON.parse options.citation
    catch
      citation = citation.replace(/citation\:/gi,'').trim()
      citation = citation.split('title')[1].trim() if citation.indexOf('title') isnt -1
      citation = citation.replace(/^"/,'').replace(/^'/,'').replace(/"$/,'').replace(/'$/,'')
      rs.doi = citation.split('doi:')[1].split(',')[0].split(' ')[0].trim() if citation.indexOf('doi:') isnt -1
      rs.doi = citation.split('doi.org/')[1].split(',')[0].split(' ')[0].trim() if citation.indexOf('doi.org/') isnt -1
      if not rs.doi and citation.indexOf('http') isnt -1
        rs.url = 'http' + citation.split('http')[1].split(' ')[0].trim()
      try
        if citation.indexOf('|') isnt -1 or citation.indexOf('}') isnt -1
          rs.title = citation.split('|')[0].split('}')[0].trim()
        if citation.split('"').length > 2
          rs.title = citation.split('"')[1].trim()
        else if citation.split("'").length > 2
          rs.title ?= citation.split("'")[1].trim()
      try
        pts = citation.replace(/,\./g,' ').split ' '
        for pt in pts
          if not rs.year
            pt = pt.replace /[^0-9]/g,''
            if pt.length is 4
              sy = parseInt pt
              rs.year = sy if typeof sy is 'number' and not isNaN sy
      try
        if not rs.title and rs.year and citation.indexOf(rs.year) < (citation.length/4)
          rs.title = citation.split(rs.year)[1].trim()
          rs.title = rs.title.replace(')','') if rs.title.indexOf('(') is -1 or rs.title.indexOf(')') < rs.title.indexOf('(')
          rs.title = rs.title.replace('.','') if rs.title.indexOf('.') < 3
          rs.title = rs.title.replace(',','') if rs.title.indexOf(',') < 3
          rs.title = rs.title.trim()
          if rs.title.indexOf('.') isnt -1
            rs.title = rs.title.split('.')[0]
          else if rs.title.indexOf(',') isnt -1
            rs.title = rs.title.split(',')[0]
      if rs.title
        try
          bt = citation.split(rs.title)[0]
          bt = bt.split(rs.year)[0] if rs.year and bt.indexOf(rs.year) isnt -1
          bt = bt.split(rs.url)[0] if rs.url and bt.indexOf(rs.url) > 0
          bt = bt.replace(rs.url) if rs.url and bt.indexOf(rs.url) is 0
          bt = bt.replace(rs.doi) if rs.doi and bt.indexOf(rs.doi) is 0
          bt = bt.replace('.','') if bt.indexOf('.') < 3
          bt = bt.replace(',','') if bt.indexOf(',') < 3
          bt = bt.substring(0,bt.lastIndexOf('(')) if bt.lastIndexOf('(') > (bt.length-3)
          bt = bt.substring(0,bt.lastIndexOf(')')) if bt.lastIndexOf(')') > (bt.length-3)
          bt = bt.substring(0,bt.lastIndexOf(',')) if bt.lastIndexOf(',') > (bt.length-3)
          bt = bt.substring(0,bt.lastIndexOf('.')) if bt.lastIndexOf('.') > (bt.length-3)
          bt = bt.trim()
          if bt.length > 6
            if bt.indexOf(',') isnt -1
              rs.author = []
              rs.author.push({name: ak}) for ak in bt.split(',')
            else
              rs.author = [{name: bt}]
        try
          rmn = citation.split(rs.title)[1]
          rmn = rmn.replace(rs.url) if rs.url and rmn.indexOf(rs.url) isnt -1
          rmn = rmn.replace(rs.doi) if rs.doi and rmn.indexOf(rs.doi) isnt -1
          rmn = rmn.replace('.','') if rmn.indexOf('.') < 3
          rmn = rmn.replace(',','') if rmn.indexOf(',') < 3
          rmn = rmn.trim()
          if rmn.length > 6
            rs.journal = rmn
            rs.journal = rs.journal.split(',')[0].replace(/in /gi,'').trim() if rmn.indexOf(',') isnt -1
            rs.journal = rs.journal.replace('.','') if rs.journal.indexOf('.') < 3
            rs.journal = rs.journal.replace(',','') if rs.journal.indexOf(',') < 3
            rs.journal = rs.journal.trim()
      try
        if rs.journal
          rmn = citation.split(rs.journal)[1]
          rmn = rmn.replace(rs.url) if rs.url and rmn.indexOf(rs.url) isnt -1
          rmn = rmn.replace(rs.doi) if rs.doi and rmn.indexOf(rs.doi) isnt -1
          rmn = rmn.replace('.','') if rmn.indexOf('.') < 3
          rmn = rmn.replace(',','') if rmn.indexOf(',') < 3
          rmn = rmn.trim()
          if rmn.length > 4
            rmn = rmn.split('retrieved')[0] if rmn.indexOf('retrieved') isnt -1
            rmn = rmn.split('Retrieved')[0] if rmn.indexOf('Retrieved') isnt -1
            rs.volume = rmn
            if rs.volume.indexOf('(') isnt -1
              rs.volume = rs.volume.split('(')[0]
              rs.volume = rs.volume.trim()
              try
                rs.issue = rmn.split('(')[1].split(')')[0]
                rs.issue = rs.issue.trim()
            if rs.volume.indexOf(',') isnt -1
              rs.volume = rs.volume.split(',')[0]
              rs.volume = rs.volume.trim()
              try
                rs.issue = rmn.split(',')[1]
                rs.issue = rs.issue.trim()
            if rs.volume
              try
                delete rs.volume if isNaN parseInt rs.volume
            if rs.issue
              if rs.issue.indexOf(',') isnt -1
                rs.issue = rs.issue.split(',')[0].trim()
              try
                delete rs.issue if isNaN parseInt rs.issue
            if rs.volume and rs.issue
              try
                rmn = citation.split(rs.journal)[1]
                rmn = rmn.split('retriev')[0] if rmn.indexOf('retriev') isnt -1
                rmn = rmn.split('Retriev')[0] if rmn.indexOf('Retriev') isnt -1
                rmn = rmn.split(rs.url)[0] if rs.url and rmn.indexOf(rs.url) isnt -1
                rmn = rmn.split(rs.doi)[0] if rs.doi and rmn.indexOf(rs.doi) isnt -1
                rmn = rmn.substring(rmn.indexOf(rs.volume)+(rs.volume+'').length)
                rmn = rmn.substring(rmn.indexOf(rs.issue)+(rs.issue+'').length)
                rmn = rmn.replace('.','') if rmn.indexOf('.') < 2
                rmn = rmn.replace(',','') if rmn.indexOf(',') < 2
                rmn = rmn.replace(')','') if rmn.indexOf(')') < 2
                rmn = rmn.trim()
                if not isNaN parseInt rmn.substring(0,1)
                  rs.pages = rmn.split(' ')[0].split('.')[0].trim()
                  rs.pages = rs.pages.split(', ')[0] if rs.pages.length > 5
      if not rs.author and citation.indexOf('et al') isnt -1
        cn = citation.split('et al')[0].trim()
        if citation.indexOf(cn) is 0
          rs.author = [{name: cn + 'et al'}]
      if rs.title and not rs.volume
        try
          clc = citation.split(rs.title)[1].toLowerCase().replace('volume','vol').replace('vol.','vol').replace('issue','iss').replace('iss.','iss').replace('pages','page').replace('pp','page')
          if clc.indexOf('vol') isnt -1
            rs.volume = clc.split('vol')[1].split(',')[0].split('(')[0].split('.')[0].split(' ')[0].trim()
          if not rs.issue and clc.indexOf('iss') isnt -1
            rs.issue = clc.split('iss')[1].split(',')[0].split('.')[0].split(' ')[0].trim()
          if not rs.pages and clc.indexOf('page') isnt -1
            rs.pages = clc.split('page')[1].split('.')[0].split(', ')[0].split(' ')[0].trim()

  return rs
