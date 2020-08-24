
import Future from 'fibers/future'
import unidecode from 'unidecode'

#oab_find.remove '*'
#oab_catalogue.remove '*'

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
      console.log citation
      rs.doi = citation.split('doi:')[1].split(',')[0].split(' ')[0].trim() if citation.indexOf('doi:') isnt -1
      rs.doi = citation.split('doi.org/')[1].split(',')[0].split(' ')[0].trim() if citation.indexOf('doi.org/') isnt -1
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
  return rs
  
API.service.oab.ftitle = (title) ->
  # a useful way to show a title (or other string) as one long string with no weird characters
  ft = ''
  for tp in unidecode(title.toLowerCase()).replace(/[^a-z0-9 ]/g,'').replace(/ +/g,' ').split(' ')
    ft += tp
  return ft

API.service.oab.finder = (metadata) ->
  if metadata.citation?
    for k of c = API.service.oab.citation metadata.citation
      metadata[k] ?= c[k]
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
      API.log 'find request blacklisted for ' + JSON.stringify opts
      return 400
    else
      return API.service.oab.find opts
API.add 'service/oab/find', get:_find, post:_find

API.add 'service/oab/finds', () -> return oab_find.search this, {exclude: ['config']}
API.add 'service/oab/found', () -> return oab_catalogue.search this, {restrict:[{exists: {field:'url'}}], exclude: ['config']}

API.add 'service/oab/catalogue', () -> return oab_catalogue.search this
API.add 'service/oab/catalogue/finder', 
  get: () ->
    res = query: API.service.oab.finder this.queryParams
    res.count = oab_catalogue.count res.query
    res.find = oab_catalogue.finder res.query
    return res
API.add 'service/oab/catalogue/:cid', get: () -> return oab_catalogue.get this.urlParams.cid

API.add 'service/oab/metadata',
  get: () -> return API.service.oab.metadata this.queryParams
  post: () -> return API.service.oab.metadata this.request.body



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
      afnd.data.meta.article = _.clone(afnd.v2.metadata) if afnd.v2.metadata?
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
    info = _.clone input # so it does not get wiped during loops
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
        metadata[i] ?= info[i] if typeof info[i] is 'string' or _.isArray info[i] # not expecting objects back here by this point


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
  options.metadata = if options.metadata is true then ['title','doi','author','journal','issn','volume','issue','page','published','year'] else if _.isArray(options.metadata) then options.metadata else []
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
  if options.title and (options.title.indexOf('{') isnt -1 or (options.title.replace('...','').match(/\./gi) ? []).length > 3 or (options.title.match(/\(/gi) ? []).length > 2)
    options.citation = options.title # titles that look like citations
    delete options.title
  try _get.metadata(API.service.oab.citation options.citation) if options.citation?
  metadata.title = metadata.title.replace(/(<([^>]+)>)/g,'').replace(/\+/g,' ').trim() if typeof metadata.title is 'string'
  delete metadata.doi if typeof metadata.doi isnt 'string' or metadata.doi.indexOf('10.') isnt 0
  if typeof metadata.doi is 'string' # gets rid of some junk passed in after doi in some cases
    metadata.doi = metadata.doi.split(' ')[0]
    metadata.doi = metadata.doi.replace('doi.org/','').trim() if metadata.doi.indexOf('doi.org/') is 0
    metadata.doi = metadata.doi.replace('doi:','').trim() if metadata.doi.indexOf('doi:') is 0

  options.permissions ?= options.plugin is 'shareyourpaper' # don't get permissions by default now that the permissions check could take longer
  options.ill ?= (options.from? or options.config?) and options.plugin is 'instantill' # get ILL info too if necessary
  options.bing = API.settings?.service?.openaccessbutton?.resolve?.bing isnt false and API.settings?.service?.openaccessbutton?.resolve?.bing?.use isnt false

  # switch exlibris URLs for titles, which the scraper knows how to extract, because the exlibris url would always be the same
  if not metadata.title and content and typeof options.url is 'string' and (options.url.indexOf('alma.exlibrisgroup.com') isnt -1 or options.url.indexOf('/exlibristest') isnt -1)
    delete options.url
    res.exlibris = true

  res.plugin = options.plugin if options.plugin?
  res.from = options.from if options.from?
  res.find = options.find ? true
  # other possible sources are ['base','dissemin','share','core','openaire','bing','fighsare']
  # can also add journal, which checks doaj for the journal info - later may check more about journals
  res.sources = options.sources ? ['oabutton','catalogue','oadoi','crossref','epmc','doaj','reverse','scrape']
  res.sources.push('bing') if options.bing and (options.plugin in ['widget','oasheet'] or options.from in ['illiad','clio'] or res.exlibris)
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

  API.log msg: 'OAB finding academic content', level: 'debug', metadata: JSON.stringify metadata

  # prep complete ==============================================================


  # set a demo tag in certain cases ====================================
  # e.g. for instantill/shareyourpaper/other demos - dev and live demo accounts
  res.demo = options.demo
  res.demo ?= true if (metadata.doi is '10.1234/567890' or (metadata.doi? and metadata.doi.indexOf('10.1234/oab-syp-') is 0)) or metadata.title is 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL' or options.from in ['qZooaHWRz9NLFNcgR','eZwJ83xp3oZDaec86']
  res.test ?= true if res.demo # don't save things coming from the demo accounts into the catalogue later

  # sub-processes to loop call until all result parts are found ================
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
      #res.permissions ?= catalogued.permissions if catalogued.permissions? and not catalogued.permissions?.error? and (catalogued.metadata?.journal? or catalogued.metadata?.issn?)
      if 'oabutton' in res.sources
        if catalogued.url? # within or without refresh time, if we have already found it, re-use it
          _get.metadata catalogued.metadata
          res.cached = true
          res.found = catalogued.found
          res.url = catalogued.url
          res.url = res.url[0] if _.isArray res.url
        else if catalogued.createdAt > Date.now() - res.refresh*86400000
          _get.metadata catalogued.metadata # it is in the catalogue but we don't have a link for it, and it is within refresh days old, so re-use the metadata from it
          res.cached = true

  _get.catalogue = () ->
    inc = API.service.academic.article.doi metadata.doi
    _get.metadata(inc) if inc?
    
  _get.reverse = () ->
    if not crs?.doi? and typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2
      check = API.use.crossref.reverse metadata.title, undefined, true
      crs = check if check.doi and check.title? and check.title.length <= metadata.title.length*1.2 and check.title.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(check.title.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1
    if not crs?.doi? and options.citation?
      check = API.use.crossref.reverse options.citation, undefined, true
      crs = check if check.doi and check.title? and check.title.length and (not metadata.year? or not check.year? or metadata.year is check.year) and (not metadata.journal? or not check.journal? or metadata.journal.toLowerCase().replace(/['".,\/\^&\*;:!\?#\$%{}=\-_`~()]/g,' ').replace(/\s{2,}/g,' ').trim() is check.journal.toLowerCase().replace(/['".,\/\^&\*;:!\?#\$%{}=\-_`~()]/g,' ').replace(/\s{2,}/g,' ').trim())
    _get.metadata(crs) if crs?
    if crs?.url? and crs.redirect isnt false and crs.licence? and crs.licence.indexOf('creativecommons') isnt -1
      res.url = crs.redirect ? crs.url
      res.found.crossref = res.url

  #_get.citation = () ->
  # citation parser could be separated from reverse lookup above,
  # or could actually run a citation parser on the incoming string
  # but for now, pulling the title and using the above seems to be working well enough

  _get.bing = () ->
    API.settings.service.openaccessbutton.resolve.bing = {max:1000,cap:'30days'} if API.settings?.service?.openaccessbutton?.resolve?.bing is true
    cap = if API.settings?.service?.openaccessbutton?.resolve?.bing?.cap? then API.job.cap(API.settings.service.openaccessbutton?.resolve?.bing?.max ? 1000, API.settings.service.openaccessbutton?.resolve?.bing?.cap ? '30days','oabutton_bing') else undefined
    if cap?.capped
      res.capped = true
    else
      mct = unidecode(metadata.title.toLowerCase()).replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ')
      bing = API.use.microsoft.bing.search mct, true, 2592000000, API.settings.use.microsoft.bing.key # search bing for what we think is a title (caching up to 30 days)
      bct = unidecode(bing.data[0].name.toLowerCase()).replace('(pdf)','').replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ')
      if not API.service.oab.blacklist(bing.data[0].url) and mct.replace(/ /g,'').indexOf(bct.replace(/ /g,'')) is 0 # if the URL is usable and tidy bing title is not a partial match to the start of the provided title, we won't do anything with it
        try
          if bing.data[0].url.toLowerCase().indexOf('.pdf') is -1 or mct.replace(/[^a-z0-9]+/g, "").indexOf(bing.data[0].url.toLowerCase().split('.pdf')[0].split('/').pop().replace(/[^a-z0-9]+/g, "")) is 0
            options.url = bing.data[0].url.replace(/"/g,'')
          else
            content = API.convert.pdf2txt(bing.data[0].url)
            content = content.substring(0,1000) if content.length > 1000
            content = content.toLowerCase().replace(/[^a-z0-9]+/g, "").replace(/\s\s+/g, '')
            if content.indexOf(mct.replace(/ /g, '')) isnt -1
              options.url = bing.data[0].url.replace(/"/g,'')
        catch
          options.url = bing.data[0].url.replace(/"/g,'')

  _get.journal = () ->
    dres = API.use.doaj.journals.search(if metadata.issn then 'issn:"'+metadata.issn+'"' else 'bibjson.journal.title:"'+metadata.journal+'"')
    res.checked.push('doaj') if 'doaj' not in res.checked
    if dres?.results?.length > 0
      for ju in dres.results[0].bibjson.link
        if ju.type is 'homepage'
          _get.metadata API.use.doaj.articles.format dres.results[0]
          res.journal = ju.url
          res.found.doaj = ju.url
          break

  _get.content = () ->
    _get.metadata API.service.oab.scrape undefined, content 

  _get.scrape = () ->
    _get.metadata API.service.oab.scrape options.url

  _get.permissions = () ->
    res.permissions ?= API.service.oab.permissions metadata, undefined, undefined, undefined, (options.config ? options.from)

  _get.ill = () ->
    res.ill ?= {} # terms and openurl used to be set here, but now all done in embed
    try res.ill.subscription = API.service.oab.ill.subscription (options.config ? options.from), metadata, res.refresh


  # loop runner ================================================================
  times = []
  _running = {}
  _run = (src, which='') ->
    if not _got() or (res.find and not res.url) # check again due to any delay in loops
      runs = Date.now()
      if typeof _get[src] is 'function'
        try _get[src]()
      else
        try
          rs = false
          if src is 'oadoi' and  which is 'doi' and metadata[which]?
            rs = API.use.oadoi.doi metadata.doi, true
          else if src is 'crossref' and which in ['doi','title']
            # crossref title lookup can accept full metadata object to compare additional metadata possibly in a citation
            if which is 'title'
              if options.citation?
                mq = _.clone metadata
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
            rs = API.use.europepmc[if which is 'id' then (if metadata.pmcid then 'pmc' else 'pmid') else which] (if which is 'id' then (metadata.pmcid ? metadata.pmid) else metadata[which]), true
          else if src is 'doaj' and which in ['doi','title']
            rs = API.use.doaj.articles[which] metadata[which]
          else if typeof API.use[src]?[which] is 'function' and metadata[which]?
            # other possible sources to check title or doi are ['base','dissemin','share','core','openaire','fighsare'] 
            # but we do not use them by default any more
            rs = API.use[src][which] metadata[which]
          if typeof rs is 'object'
            mt = rs.title ? rs.dctitle ? rs.bibjson?.title ? rs.metadata?['oaf:result']?.title?.$
            if (which isnt 'title' or (mt and ((mt.length > metadata.title.length and metadata.title.split(' ').length > 5 and mt.toLowerCase().replace(/[^a-z0-9]/g,'').indexOf(metadata.title.toLowerCase().replace(/[^a-z0-9]/g,'')) is 0) or (mt.length <= metadata.title.length*1.2 and mt.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(mt.toLowerCase().replace(' ','').replace(' ','').split(' ')[0]) is 0))))
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
  done = {}
  used = []
  _loop = () ->
    dd = _.clone done
    md = _.clone metadata

    if not catalogued?
      ul = used.length
      more = false
      for tid in ['doi','title','pmid','pmcid','url']
        if metadata[tid] and tid not in used
          more = tid
          used.push tid
      if more
        done['oabutton'+more] = true
        if ul then _prl('oabutton') else _run('oabutton') # everything else waits for one check of the catalogue

    if not res.cached or (options.metadata.length and not _got()) or (not res.cached and res.find and not res.url)
      if metadata.doi and not done.dois
        done.dois = true
        for src in res.sources
          _prl(src, 'doi') if src not in ['oabutton','reverse','scrape','bing']
      else if (metadata.pmcid or metadata.pmid) and not done.epmcid
        done.epmcid = true
        _prl('epmc','id')
      else if _.isEmpty(_running) and not metadata.doi #or done.dois)
        if typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and not done.titles
          done.titles = true
          for src in res.sources
            _prl(src, 'title') if src not in ['oadoi','oabutton','catalogue','reverse','scrape','bing','crossref'] # TODO remove crossref from this list once our crossref title lookup works better
        else if not done.reverse and 'reverse' in res.sources and ((typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2) or options.citation)
          done.reverse = true
          _run 'reverse'
        else if (not metadata.pmcid and not metadata.pmid) or done.epmcid
          if not metadata.title or (done.titles and (done.bing or not options.bing or 'bing' not in res.sources))
            if not done.content and content
              done.content = true
              _run 'content'
            else if options.url and not done.scrape and 'scrape' in res.sources
              done.scrape = true
              _run 'scrape'
          else if not done.bing and not options.url and typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2 and options.bing and 'bing' in res.sources
            done.bing = true
            _run 'bing'

    if metadata.doi and options.permissions and not done.permissions
      done.permissions = true
      _prl 'permissions'

    if not done.journal and (metadata.journal or metadata.issn) and 'journal' in res.sources and res.find and not res.url and not res.journal and (not metadata.doi or done.dois) and (not metadata.title or done.titles)
      done.journal = true
      _prl 'journal'

    if metadata.doi
      for rn of _running
        delete _running[rn] if rn.indexOf('title') isnt -1 # don't wait for running title lookups if doi found since they started
          
    if (not _got() or (res.find and not res.url)) and (not _.isEmpty(_running) or not _.isEqual(dd, done) or not _.isEqual(md, metadata))
      future = new Future()
      Meteor.setTimeout (() -> future.return()), 50
      future.wait()
      #console.log _running
      _loop()
  _loop()
  
  _get.oabutton() if not catalogued? # final check for a previous catalogue entry, with everything we know so far

  if options.ill and (metadata.doi or metadata.title) and not done.ill
    done.ill = true # have to do this after loop so that all metaadata is available for subscription lookup
    _run 'ill' # otherwise could put into loop above and call with _prl 'ill'

  # processing done, save and return ===========================================
  
  # update or create a catalogue record, and a find record, without waiting
  _save = (id, data, fnd) ->
    if data? and not _.isEmpty data
      if id
        oab_catalogue.update id, data
      else
        fnd.catalogue = oab_catalogue.insert data
    fndc = _.clone fnd
    delete fnd.permissions # don't store permissions in finds, only in catalogue
    oab_find.insert fnd
  _sv = (id, data, fnd) -> Meteor.setTimeout (() -> _save(id, data, fnd)), 1

  # certain user-provided search values are allowed to override any that we could find ourselves, and we note that we got these from the user
  for uo in ['title','journal','year','doi']
    if options[uo] and options[uo].length and options[uo] isnt metadata[uo]
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
        upd.metadata = _.clone metadata
        for m of catalogued.metadata
          upd.metadata[m] ?= catalogued.metadata[m]
        for cu in (if typeof catalogued.metadata?.url is 'string' then [catalogued.metadata.url] else if _.isArray(catalogued.metadata?.url) then catalogued.metadata.url else [])
          upd.metadata.url.push(cu) if cu not in upd.metadata.url
      upd.sources = _.union(res.sources, catalogued.sources) if JSON.stringify(res.sources.sort()) isnt JSON.stringify catalogued.sources.sort()
      uc = _.union res.checked, catalogued.checked
      upd.checked = uc if JSON.stringify(uc.sort()) isnt JSON.stringify catalogued.checked.sort()
      if not _.isEmpty res.found
        upd.found = _.clone res.found
        for cf of catalogued.found
          upd.found[cf] ?= catalogued.found[cf]
      upd.permissions = res.permissions if res.permissions? and not res.permissions.error? and (not catalogued.permissions? or not _.isEqual res.permissions, catalogued.permissions)
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
        permissions: res.permissions if res.permissions? and not res.permissions.error?
      fl.ftitle = API.service.oab.ftitle(metadata.title) if typeof metadata.title is 'string'
      fl.usermetadata = res.usermetadata if res.usermetadata?
      _sv undefined, fl, res
  else
    _sv undefined, undefined, res

  return res



