
import Future from 'fibers/future'
import unidecode from 'unidecode'

#oab_find.remove '*'
#oab_catalogue.remove '*'
# an unnecessary change

API.service.oab.ftitle = (title) ->
  # a useful way to show a title (or other string) as one long string with no weird characters
  ft = ''
  for tp in unidecode(title.toLowerCase()).replace(/[^a-z0-9 ]/g,'').replace(/ +/g,' ').split(' ')
    ft += tp
  return ft

API.service.oab._finder = (metadata) ->
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
  finder = API.service.oab._finder metadata
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
API.add 'service/oab/finds', () -> return oab_find.search this
API.add 'service/oab/found', () -> return oab_catalogue.search this, {restrict:[{exists: {field:'url'}}]}
API.add 'service/oab/catalogue', () -> return oab_catalogue.search this
API.add 'service/oab/catalogue/:cid', get: () -> return oab_catalogue.get this.urlParams.cid

API.add 'service/oab/metadata',
  get: () -> return API.service.oab.metadata this.queryParams
  post: () -> return API.service.oab.metadata this.request.body

#API.add 'service/oab/abbreviate/:journal', get: () -> return API.service.oab.abbreviate this.urlParams.journal


# exists for legacy reasons, _avail should be altered to make sure the _find returns what _avail used to
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



# legacy wrapper
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
  res = {url: false, checked: []}

  options = API.tdm.clean options
  metadata = API.tdm.clean metadata
  
  # libraries want to know the input that was searched, it could be one of various params depending on the source
  # stringify it and store it just in case
  try
    for o of options
      if o in ['doi','title','id','pmid','pmcid','pmc','url','citation','q']
        res.input ?= ''
        res.input += ', ' if res.input.length
        res.input += o + ': "' + options[o] + '"'

  _get = (metadata, info) ->
    for i of info
      metadata[i] ?= info[i] if info[i]
  _got = (obj=metadata) ->
    for w in options.metadata
      if not obj[w]?
        return false
    return true

  _get_formatted_crossref = () ->
    if (not _got() or (res.find and not res.url)) and ('crossref' in res.sources or 'reverse' in res.source)
      if metadata.doi? and 'crossref' in res.sources
        res.checked.push('crossref') if 'crossref' not in res.checked
        crs = API.use.crossref.works.doi metadata.doi, true
        if not crs?.crossref_type
          res.doi_not_in_crossref = metadata.doi
          delete options.url if typeof options.url is 'string' and options.url.indexOf('doi.org/' + metadata.doi) isnt -1
          delete metadata.doi
          delete options.doi # don't allow the user-provided data to later override if we can't validate it on crossref
      else if 'crossref' in res.sources and metadata.title? and metadata.title.length > 8 and metadata.title.split(' ').length > 2
        res.checked.push('crossref') if 'crossref' not in res.checked
        crs = API.use.crossref.works.title metadata.title, true
      if not crs?.doi? and options.citation?
        # sometimes the citation passed to crossref title search (which is actually a bibliographic metadata search now) can find things better than reverse lookup, and better than just title search, so try that before reversing
        res.checked.push('crossref') if 'crossref' not in res.checked
        crs = API.use.crossref.works.title options.citation, true
      if not crs?.doi? and not res.doi_not_in_crossref and not options.reversed and 'reverse' in res.sources and (options.citation? or metadata.title?)
        if not crs?.doi?
          res.checked.push('reverse') if 'reverse' not in res.checked
          if metadata.title? and metadata.title.length > 8 and metadata.title.split(' ').length > 2
            try
              check = API.use.crossref.reverse metadata.title, undefined, true
              crs = check if check.doi and check.title? and check.title.length <= metadata.title.length*1.2 and check.title.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(check.title.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1
          if not crs?.doi? and options.citation?
            try
              check = API.use.crossref.reverse options.citation, undefined, true
              crs = check if check.doi and check.title? and check.title.length and (not metadata.year? or not check.year? or metadata.year is check.year) and (not metadata.journal? or not check.journal? or metadata.journal.toLowerCase().replace(/['".,\/\^&\*;:!\?#\$%{}=\-_`~()]/g,' ').replace(/\s{2,}/g,' ').trim() is check.journal.toLowerCase().replace(/['".,\/\^&\*;:!\?#\$%{}=\-_`~()]/g,' ').replace(/\s{2,}/g,' ').trim())
      _get(metadata, crs) if crs?
      res.found.crossref = (res.redirect ? res.url) if crs?.url? and crs.licence? and crs.licence.indexOf('creativecommons') isnt -1
  _get_formatted_europepmc = () ->
    if (not _got() or (res.find and not res.url)) and 'epmc' in res.sources and (metadata.doi or metadata.pmid or metadata.pmcid or (metadata.title and metadata.title.length > 8 and metadata.title.split(' ').length > 2))      
      res.checked.push('epmc') if 'epmc' not in res.checked
      ec = (if metadata.doi then API.use.europepmc.doi(metadata.doi) else if metadata.title then API.use.europepmc.title(metadata.title) else if metadata.pmid then API.use.europepmc.pmid(metadata.pmid) else API.use.europepmc.pmc metadata.pmcid)
      _get(metadata, ec) if ec?
      res.found.epmc = ec.url if ec?.url

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
  metadata.title ?= options.title.trim() if typeof options.title is 'string'
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
        metadata.doi = dd
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
      metadata.title = options.url
    delete options.url if options.url.indexOf('http') isnt 0 or options.url.indexOf('.') is -1
  metadata.doi = metadata.doi.replace('doi.org/','').trim() if metadata.doi? and metadata.doi.indexOf('doi.org/') is 0
  metadata.doi = metadata.doi.replace('doi:','').trim() if metadata.doi? and metadata.doi.indexOf('doi:') is 0
  delete metadata.doi if metadata.doi and metadata.doi.indexOf('10.') isnt 0
  if metadata.title and (metadata.title.indexOf('{') isnt -1 or (metadata.title.replace('...','').match(/\./gi) || []).length > 3 or (metadata.title.match(/\(/gi) || []).length > 2)
    options.citation = metadata.title # titles that look like citations
    delete metadata.title
  if options.citation? and not metadata.title and not metadata.doi
    options.citation = options.citation.replace(/citation\:/gi,'').trim()
    if options.citation.indexOf('doi:') isnt -1
      metadata.doi = options.citation.split('doi:')[1].split(',')[0].split(' ')[0].trim()
    else if options.citation.indexOf('{') is 0 or options.citation.indexOf('[') is 0 # look for dumped citation styles
      try _get metadata, JSON.parse options.citation
    else
      try
        options.citation = options.citation.split('title')[1].trim() if options.citation.indexOf('title') isnt -1
        options.citation = options.citation.trim("'").trim('"')
        if options.citation.indexOf('|') isnt -1
          metadata.title = options.citation.split('|')[0].trim()
        else if options.citation.indexOf('}') isnt -1
          metadata.title = options.citation.split('}')[0].trim()
        else if options.citation.split('"').length > 2
          metadata.title = options.citation.split('"')[1].trim()
        else if options.citation.split("'").length > 2
          metadata.title = options.citation.split("'")[1].trim()
  metadata.title = metadata.title.replace(/(<([^>]+)>)/g,'').replace(/\+/g,' ').trim() if typeof metadata.title is 'string'

  options.permissions ?= false # don't get permissions by default now that the permissions check could take longer

  res.plugin = options.plugin if options.plugin?
  res.from = options.from if options.from?
  res.all = options.all ? false
  res.parallel = options.parallel ? true
  res.find = options.find ? true
  # other possible sources are ['base','dissemin','share','core','openaire','bing','fighsare']
  res.sources = options.sources ? ['oabutton','oadoi','crossref','epmc','doaj','reverse','scrape']
  ou = if typeof options.url is 'string' then options.url else if _.isArray(options.url) then options.url[0] else undefined
  res.sources.push('bing') if options.plugin in ['widget','oasheet'] or options.from in ['illiad','clio'] or (ou? and ou.indexOf('alma.exlibrisgroup.com') isnt -1)
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

  API.log msg: 'OAB finding academic content', level: 'debug', metadata: JSON.stringify metadata

  # special cases for instantill/shareyourpaper/other demos - dev and live demo accounts that always return a fixed answer
  demodoi = metadata.doi is '10.1234/567890' or (metadata.doi? and metadata.doi.indexOf('10.1234/oab-syp-') is 0)
  if (options.plugin is 'instantill' or options.plugin is 'shareyourpaper') and (demodoi or metadata.title is 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL') and options.from in ['qZooaHWRz9NLFNcgR','eZwJ83xp3oZDaec86'] 
    # https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y
    res.metadata = {title: 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL', year: '2019', doi: metadata.doi ? '10.1234/oab-syp-aam'}
    res.metadata.journal = 'Proceedings of the 16th IFLA ILDS conference: Beyond the paywall - Resource sharing in a disruptive ecosystem'
    res.metadata.author = [{given: 'Mike', family: 'Paxton'}, {given: 'Gary', family: 'Maixner III'}, {given: 'Joseph', family: 'McArthur'}, {given: 'Tina', family: 'Baich'}]
    res.ill = {openurl: ""}
    res.ill.subscription = {findings:{}, uid: options.from, lookups:[], error:[], url: 'https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y', demo: true}
    res.permissions = API.service.oab.permissions(metadata) if options.permissions and metadata.doi and not demodoi
    return res
    
  if not metadata.title and content and typeof options.url is 'string' and (options.url.indexOf('alma.exlibrisgroup.com') isnt -1 or options.url.indexOf('/exlibristest') isnt -1)
    # switch exlibris URLs for titles, which the scraper knows how to extract, because the exlibris url would always be the same
    delete options.url
    res.exlibris = true
    _get metadata, API.service.oab.scrape undefined, content

  if content and _.isEmpty metadata
    _get metadata, API.service.oab.scrape undefined, content
  
  # check for an entry in our catalogue already
  used = _.keys metadata
  catalogued = undefined
  _findoab = () ->
    catalogued = oab_catalogue.finder metadata
    # if user wants a total refresh, don't use any of it (we still search for it though, because will overwrite later with the fresh stuff)
    delete catalogued.found.oabutton if catalogued?.found?.oabutton? # fix for mistakenly cached things, we now won't record as found in OAB, just show as cached response
    if _.isArray catalogued?.found?.epmc?
      delete catalogued.found.epmc 
      delete catalogued.url if _.isArray catalogued.url
      delete catalogued.metadata.url if _.isArray catalogued.metadata?.url
    if catalogued? and res.refresh isnt 0
      #res.permissions ?= catalogued.permissions if catalogued.permissions?.permissions? and not catalogued.permissions?.error? and (catalogued.metadata?.journal? or catalogued.metadata?.issn?)
      if 'oabutton' in res.sources
        res.checked.push('oabutton') if 'oabutton' not in res.checked
        if catalogued.url? # within or without refresh time, if we have already found it, re-use it
          _get metadata, catalogued.metadata
          res.cached = true # no need for further finding if we have the url and all necessary metadata
          res.url = catalogued.url
          res.url = res.url[0] if _.isArray res.url
        else if catalogued.createdAt > Date.now() - res.refresh*86400000
          _get metadata, catalogued.metadata # it is in the catalogue but we don't have a link for it, and it is within refresh days old, so re-use the metadata from it
          res.cached = true # and cause an immediate return, we don't bother looking for everything again if we already couldn't find it within a given refresh window
  _findoab()

  # TODO update requests so successful ones write the source to the catalogue - but updating requests is not priority yet, so not doing right now

  if not res.cached or not _got() or options.permissions and not res.permissions?
    # check crossref for metadata if we don't have enough, but do already have a doi
    _get_formatted_crossref()
    _get_formatted_europepmc() if not metadata.doi # check epmc if we don't have doi - it can be checked later for other things if necessary

    # if still no doi, but do have title or pmid or pmc, and don't have a URL or some provided page content, try to find a URL via bing
    if (not _got() or (res.find and not res.url)) and not metadata.doi and not options.url and not content and (metadata.title or metadata.pmid or metadata.pmcid) and 'bing' in res.sources and API.settings?.service?.openaccessbutton?.resolve?.bing isnt false and API.settings?.service?.openaccessbutton?.resolve?.bing?.use isnt false
      API.settings.service.openaccessbutton.resolve.bing = {max:1000,cap:'30days'} if API.settings?.service?.openaccessbutton?.resolve?.bing is true
      try
        cap = if API.settings?.service?.openaccessbutton?.resolve?.bing?.cap? then API.job.cap(API.settings.service.openaccessbutton?.resolve?.bing?.max ? 1000, API.settings.service.openaccessbutton?.resolve?.bing?.cap ? '30days','oabutton_bing') else undefined
        if cap?.capped
          res.capped = true
        else
          res.checked.push 'bing'
          mct = if metadata.title then unidecode(metadata.title.toLowerCase()).replace(/[^a-z0-9 ]+/g, " ").replace(/\s\s+/g, ' ') else if metadata.pmid then metadata.pmid else metadata.pmcid
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
  
    # if we have a url or content but no doi or title yet, try scraping the url/content
    if (not _got() or (res.find and not res.url)) and not metadata.doi and not metadata.title and ((options.url and 'scrape' in res.sources) or content)
      res.checked.push 'scrape' if not content? # scrape the page if we have to - this is slow, so we hope not to do this much
      sc = API.service.oab.scrape options.url, content
      if sc?.url?
        options.url ?= sc.url
        delete sc.url
      _get(metadata, sc) if sc?
      _get_formatted_crossref() # try crossref / epmc / reverse if we found useful metadata now
      _get_formatted_europepmc() if not metadata.doi and 'epmc' not in res.checked # don't bother if we were already able to look, e.g. by pmcid or pmid

    # we can get a 404 for an article behind a loginwall if the service does not do splash pages,
    # and then we can accidentally get the article that exists called "404 not found". So we just don't
    # run checks for titles that start with 404
    # See https://github.com/OAButton/discussion/issues/931
    # this is the article: http://research.sabanciuniv.edu/34037/
    delete metadata.title if metadata.title? and (metadata.title is 404 or metadata.title.indexOf('404') is 0)
  
    # all sources that have not yet been checked, that could find us an article, are now checked in parallel
    # by this point, by default, it would be oadoi, doaj
    if (not _got() or (res.find and not res.url)) and (metadata.doi or (metadata.title and metadata.title.length > 8 and metadata.title.split(' ').length > 2))
      did = 0
      _run = (src, which) ->
        try
          if not res.url or res.all
            rs = false
            # if using title clean it up a bit try metadata.title = metadata.title.toLowerCase().replace(/(<([^>]+)>)/g,'')
            if src is 'oadoi'
              rs = API.use.oadoi.doi(metadata.doi, true) if which is 'doi'
            else if src is 'crossref'
              rs = API.use.crossref.works[which] metadata[which], true
            else if src is 'epmc'
              rs = API.use.europepmc[which] metadata[which], true
            else if src is 'doaj'
              rs = API.use.doaj.articles[which] metadata[which]
            else
              rs = API.use[src][which] metadata[which]
              # other possible sources are ['base','dissemin','share','core','openaire','fighsare'] but we do not use them explicitly any more so don't list them explicitly here
            res.checked.push(src) if src not in res.checked
            if rs isnt false
              mt = rs.title ? rs.dctitle ? rs.bibjson?.title ? rs.metadata?['oaf:result']?.title?.$
              if rs?.url and (which isnt 'title' or (mt and mt.length <= metadata.title.length*1.2 and mt.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(mt.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1))
                if rs.redirect isnt false
                  res.redirect = if rs.redirect then rs.redirect else rs.url
                  res.url = res.redirect
                  res.found[src] ?= res.url
                metadata.licence ?= rs.licence
                metadata.licence ?= rs.best_oa_location?.license if rs.best_oa_location?.license
                metadata.title ?= mt if mt?
                metadata.year ?= rs.year if rs.year?
                metadata.pmid ?= rs.pmid if rs.pmid?
                metadata.journal ?= if rs.journalInfo?.journal?.title? then rs.journalInfo.journal.title.split('(')[0].trim() else if rs.journal?.title? then rs.journal.title.split('(')[0].trim() else if typeof rs.journal is 'string' then rs.journal else undefined
                metadata.issn ?= if rs.journalInfo?.journal?.issn? then rs.journalInfo.journal.issn else if rs.journal?.issn? then rs.journal.issn else if typeof rs.issn is 'string' then rs.issn else undefined
        did += 1

      _prl = (src, which) -> Meteor.setTimeout (() -> _run src, which), 10
      howmany = 0
      for src in res.sources
        if res.url and not res.all
          break
        else if src not in ['oabutton','reverse','bing','scrape'] # these ones will have been checked already
          if src not in ['epmc','crossref'] or src not in res.checked # crossref and maybe epmc probably has already been checked, but can check now if not
            howmany += 1
            if res.parallel
              _prl(src, 'doi') if metadata.doi?
              _prl(src, 'title') if metadata.title and metadata.title.length > 8 and metadata.title.split(' ').length > 2
            else
              _run(src, 'doi') if metadata.doi?
              _run(src, 'title') if (not _got() or (res.find and not res.url)) and metadata.title and metadata.title.length > 8 and metadata.title.split(' ').length > 2
      whiled = 0
      while res.parallel and howmany*2 isnt did and (res.all is true or not res.url) and whiled < res.sources.length*3
        whiled += 1
        future = new Future()
        Meteor.setTimeout (() -> future.return()), 500
        future.wait()
  
    # if pmcid or pmid are required and not yet found, and epmc has not yet been checked, but we now have metadata that could be used to check it
    # do one last attempt on epmc if possible
    _get_formatted_europepmc() if 'epmc' not in res.checked
  
    # can check DOAJ for journal and perhaps get some metadata from that
    if (not _got() or (res.find and not res.url)) and (metadata.journal or metadata.issn) and 'doaj' in res.sources
      try
        dres = API.use.doaj.journals.search(if metadata.issn then 'issn:"'+metadata.issn+'"' else 'bibjson.journal.title:"'+metadata.journal+'"')
        res.checked.push('doaj') if 'doaj' not in res.checked
        if dres?.results?.length > 0
          for ju in dres.results[0].bibjson.link
            if ju.type is 'homepage'
              _get metadata, API.use.doaj.articles.format dres.results[0]
              res.journal = ju.url
              res.found.doaj = ju.url
              break
  
  for uo in ['title','journal','year','doi'] # certain user-provided values override any that we do find ourselves - but don't include authors as that comes back more complex
    if options[uo] and options[uo].length and options[uo] isnt metadata[uo]
      res.usermetadata ?= catalogued?.usermetadata ? {}
      res.usermetadata[uo] ?= []
      res.usermetadata[uo].push {previous: metadata[uo], provided: options[uo], uid: options.uid, createdAt: Date.now()}
      metadata[uo] = options[uo]
      delete metadata['journal_short'] if uo is 'journal'
  for key in ['title','journal'] # tidy some metadata
    if typeof metadata[key] is 'string' and metadata[key].charAt(0).toUpperCase() isnt metadata[key].charAt(0)
      try metadata[key] = metadata[key].charAt(0).toUpperCase() + metadata[key].slice(1)

  # re-check the catalogue if we now have more metadata than we did at the initial search, so we can combine results rather than making dups
  metadata.url ?= options.url if options.url?
  if not catalogued?
    for tid in ['doi','pmid','pmcid','url','title']
      if metadata[tid] and tid not in used
        _findoab()
        break

  # fix possibly messy years
  if metadata.year?
    try
      for ms in metadata.year.split('/')
        metadata.year = ms if ms.length is 4
    try
      for md in metadata.year.split('-')
        metadata.year = md if md.length is 4
    try
      delete metadata.year if typeof metadata.year isnt 'number' and (metadata.year.length isnt 4 or metadata.year.replace(/[0-9]/gi,'').length isnt 0)
  if not metadata.year? and metadata.published?
    try
      mps = metadata.published.split('-')
      metadata.year = mps[0] if mps[0].length is 4
  if metadata.year?
    try
      delete metadata.year if typeof metadata.year isnt 'number' and (metadata.year.length isnt 4 or metadata.year.replace(/[0-9]/gi,'').length isnt 0)
    catch
      delete metadata.year
  metadata.year = metadata.year.toString() if typeof metadata.year is 'number'

  metadata.title = metadata.title.replace(/\s\s+/g,' ').trim() if typeof metadata.title is 'string'

  # remove authors if only present as strings (end users may provide them this way which causes problems in saving and re-using them
  # and author strings are not much use for discovering articles anyway
  if metadata.author?
    delete metadata.author if typeof metadata.author is 'string'
    delete metadata.author if _.isArray metadata.author and metadata.author.length > 0 and typeof metadata.author[0] is 'string'

  delete res.url if res.url is false # we put url to the top of the response for humans using false, but remove that before saving
  metadata.url ?= []
  metadata.url = [metadata.url] if typeof metadata.url is 'string'
  if catalogued?.metadata?.url?
    for cu in (if typeof catalogued.metadata.url is 'string' then [catalogued.metadata.url] else catalogued.metadata.url)
      metadata.url.push(cu) if cu not in metadata.url
  metadata.url.push(options.url) if typeof options.url is 'string' and options.url not in metadata.url
  metadata.url.push(res.url) if typeof res.url is 'string' and res.url not in metadata.url
  res.permissions ?= API.service.oab.permissions(metadata,undefined,undefined,undefined,options.from) if options.permissions and metadata.doi
  #try # as suspected this is far too loose and makes things tests that should not be, then causing them to fail on deposits. Review this at later date if still necessary
  #  res.test = true if JSON.stringify(metadata).toLowerCase().replace(/'/g,' ').replace(/"/g,' ').indexOf(' test ') isnt -1 #or (options.embedded? and options.embedded.indexOf('openaccessbutton.org') isnt -1)
  res.metadata = metadata
  

  # update or create a catalogue record
  if JSON.stringify(metadata) isnt '{}' and res.test isnt true
    res.url = res.url[0] if _.isArray res.url
    if catalogued?
      upd = {}
      upd.url = res.url if res.url? and res.url isnt catalogued.url
      upd.metadata = metadata if not _.isEqual metadata, catalogued.metadata
      upd.sources = _.union(res.sources, catalogued.sources) if JSON.stringify(res.sources.sort()) isnt JSON.stringify catalogued.sources.sort()
      uc = _.union res.checked, catalogued.checked
      upd.checked = uc if JSON.stringify(uc.sort()) isnt JSON.stringify catalogued.checked.sort()
      uf = _.extend(res.found, catalogued.found)
      upd.found = uf if not _.isEqual uf, catalogued.found
      upd.permissions = res.permissions if res.permissions? and (not catalogued.permissions? or not _.isEqual res.permissions, catalogued.permissions) and not res.permissions.error?
      upd.usermetadata = res.usermetadata if res.usermetadata?
      if typeof metadata.title is 'string'
        ftm = API.service.oab.ftitle(metadata.title)
        upd.ftitle = ftm if ftm isnt catalogued.ftitle
      oab_catalogue.update(catalogued._id, upd) if not _.isEmpty upd
      res.catalogue = catalogued._id
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
      res.catalogue = oab_catalogue.insert fl

  # get ill info for instantill widget
  if res.from? and res.plugin is 'instantill'
    res.ill = {}
    try res.ill.openurl = API.service.oab.ill.openurl res.from, metadata
    try res.ill.terms = API.service.oab.ill.terms res.from
    try res.ill.subscription = API.service.oab.ill.subscription res.from, metadata, res.refresh

  # always save a new find with a new ID, so we can track all the attempts to find something, and record who did it if known
  if options.uid
    res.uid = options.uid
    res.username = options.username
    res.email = options.email
  res.started = started
  res.ended = Date.now()
  res.took = res.ended - res.started
  oab_find.insert res
  return res







'''API.service.oab.find_too = (options={}, metadata={}, content) ->
  started = Date.now()
  res = {url: false, checked: []}

  # clean user inputs for bad characters
  options = API.tdm.clean options
  metadata = API.tdm.clean metadata
  
  # libraries want to know the input that was searched, 
  # it could be one of various params depending on the source
  # stringify it and store it just in case
  # can this be combined with the fact that we accept user-provided metadata?
  try
    for o of options
      if o in ['doi','title','id','pmid','pmcid','pmc','url','citation','q']
        res.input ?= ''
        res.input += ', ' if res.input.length
        res.input += o + ': "' + options[o] + '"'

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
  metadata.title ?= options.title.trim() if typeof options.title is 'string'
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
        metadata.doi = dd
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
      metadata.title = options.url
    delete options.url if options.url.indexOf('http') isnt 0 or options.url.indexOf('.') is -1
  metadata.doi = metadata.doi.replace('doi.org/','').trim() if metadata.doi? and metadata.doi.indexOf('doi.org/') is 0
  metadata.doi = metadata.doi.replace('doi:','').trim() if metadata.doi? and metadata.doi.indexOf('doi:') is 0
  delete metadata.doi if metadata.doi and metadata.doi.indexOf('10.') isnt 0
  if metadata.title and (metadata.title.indexOf('{') isnt -1 or (metadata.title.replace('...','').match(/\./gi) || []).length > 3 or (metadata.title.match(/\(/gi) || []).length > 2)
    options.citation = metadata.title # titles that look like citations
    delete metadata.title
  if options.citation? and not metadata.title and not metadata.doi
    options.citation = options.citation.replace(/citation\:/gi,'').trim()
    if options.citation.indexOf('doi:') isnt -1
      metadata.doi = options.citation.split('doi:')[1].split(',')[0].split(' ')[0].trim()
    else if options.citation.indexOf('{') is 0 or options.citation.indexOf('[') is 0 # look for dumped citation styles
      try _get metadata, JSON.parse options.citation
    else
      try
        options.citation = options.citation.split('title')[1].trim() if options.citation.indexOf('title') isnt -1
        options.citation = options.citation.trim("'").trim('"')
        if options.citation.indexOf('|') isnt -1
          metadata.title = options.citation.split('|')[0].trim()
        else if options.citation.indexOf('}') isnt -1
          metadata.title = options.citation.split('}')[0].trim()
        else if options.citation.split('"').length > 2
          metadata.title = options.citation.split('"')[1].trim()
        else if options.citation.split("'").length > 2
          metadata.title = options.citation.split("'")[1].trim()
  metadata.title = metadata.title.replace(/(<([^>]+)>)/g,'').replace(/\+/g,' ').trim() if typeof metadata.title is 'string'

  for uo in ['title','journal','year','doi']
    # certain user-provided values are allowed to override any that we could find ourselves, and we note that we got these from the user
    if options[uo] and options[uo].length and options[uo] isnt metadata[uo]
      res.usermetadata = {}
      res.usermetadata[uo] ?= []
      res.usermetadata[uo].push {previous: metadata[uo], provided: options[uo], uid: options.uid, createdAt: Date.now()}
      metadata[uo] = options[uo]

  options.permissions ?= false # don't get permissions by default now that the permissions check could take longer
  options.ill = res.from? and res.plugin is 'instantill' # get ILL info too if necessary
  options.bing = API.settings?.service?.openaccessbutton?.resolve?.bing isnt false and API.settings?.service?.openaccessbutton?.resolve?.bing?.use isnt false

  # switch exlibris URLs for titles, which the scraper knows how to extract, because the exlibris url would always be the same
  if not metadata.title and content and typeof options.url is 'string' and (options.url.indexOf('alma.exlibrisgroup.com') isnt -1 or options.url.indexOf('/exlibristest') isnt -1)
    delete options.url
    res.exlibris = true

  res.plugin = options.plugin if options.plugin?
  res.from = options.from if options.from?
  res.find = options.find ? true
  # other possible sources are ['base','dissemin','share','core','openaire','bing','fighsare']
  res.sources = options.sources ? ['oabutton','oadoi','crossref','epmc','doaj','reverse','scrape']
  ou = if typeof options.url is 'string' then options.url else if _.isArray(options.url) then options.url[0] else undefined
  res.sources.push('bing') if options.bing and (options.plugin in ['widget','oasheet'] or options.from in ['illiad','clio'] or (ou? and ou.indexOf('alma.exlibrisgroup.com') isnt -1))
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

  # prep complete ==============================================================
  
  API.log msg: 'OAB finding academic content', level: 'debug', metadata: JSON.stringify metadata

  # special cases for instantill/shareyourpaper/other demos - dev and live demo accounts that always return a fixed answer
  demodoi = metadata.doi is '10.1234/567890' or (metadata.doi? and metadata.doi.indexOf('10.1234/oab-syp-') is 0)
  if (options.plugin is 'instantill' or options.plugin is 'shareyourpaper') and (demodoi or metadata.title is 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL') and options.from in ['qZooaHWRz9NLFNcgR','eZwJ83xp3oZDaec86'] 
    # https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y
    res.metadata = {title: 'Engineering a Powerfully Simple Interlibrary Loan Experience with InstantILL', year: '2019', doi: metadata.doi ? '10.1234/oab-syp-aam'}
    res.metadata.journal = 'Proceedings of the 16th IFLA ILDS conference: Beyond the paywall - Resource sharing in a disruptive ecosystem'
    res.metadata.author = [{given: 'Mike', family: 'Paxton'}, {given: 'Gary', family: 'Maixner III'}, {given: 'Joseph', family: 'McArthur'}, {given: 'Tina', family: 'Baich'}]
    res.ill = {openurl: ""}
    res.ill.subscription = {findings:{}, uid: options.from, lookups:[], error:[], url: 'https://scholarworks.iupui.edu/bitstream/handle/1805/20422/07-PAXTON.pdf?sequence=1&isAllowed=y', demo: true}
    res.permissions = API.service.oab.permissions(metadata) if options.permissions and metadata.doi and not demodoi
    return res

  # sub-processes to loop call until all result parts are found ================
  
  _got = (obj=metadata) ->
    # check if we have everything we need yet
    if (options.permissions and 'permissions' not in res.checked) or (options.ill and 'ill' not in res.checked) or (res.find and not res.url)
      return false
    else
      for w in options.metadata
        if not obj[w]?
          return false
      return true

  _get = {}
  _get.metadata = (info) ->
    if typeof info is 'object' and not _.isEmpty info
      info.licence ?= info.best_oa_location.license ? info.license
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

  _get.oabutton = () ->
    catalogued = oab_catalogue.finder metadata
    if _.isArray catalogued?.found?.epmc? # can remove these fixes if catalogue is dropped
      delete catalogued.found.epmc 
      delete catalogued.url if _.isArray catalogued.url
      delete catalogued.metadata.url if _.isArray catalogued.metadata?.url
    # if user wants a total refresh, don't use any of it (we still search for it though, because will overwrite later with the fresh stuff)
    if catalogued? and res.refresh isnt 0
      # merge the usermetadata, if there already was some and we received some in this request
      #res.usermetadata = {} ?= catalogued?.usermetadata ? {}
      #res.permissions ?= catalogued.permissions if catalogued.permissions?.permissions? and not catalogued.permissions?.error? and (catalogued.metadata?.journal? or catalogued.metadata?.issn?)
      if 'oabutton' in res.sources
        res.checked.push('oabutton') if 'oabutton' not in res.checked
        if catalogued.url? # within or without refresh time, if we have already found it, re-use it
          _get.metadata catalogued.metadata
          res.cached = true # no need for further finding if we have the url and all necessary metadata
          res.url = catalogued.url
          res.url = res.url[0] if _.isArray res.url
        else if catalogued.createdAt > Date.now() - res.refresh*86400000
          _get.metadata catalogued.metadata # it is in the catalogue but we don't have a link for it, and it is within refresh days old, so re-use the metadata from it
          res.cached = true # and cause an immediate return, we don't bother looking for everything again if we already couldn't find it within a given refresh window

  _get.reverse = () ->
    crs = if options.citation? then API.use.crossref.works.title(options.citation, true) else {}
    if not crs?.doi? and _searchable_title
      check = API.use.crossref.reverse metadata.title, undefined, true
      crs = check if check.doi and check.title? and check.title.length <= metadata.title.length*1.2 and check.title.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(check.title.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1
    if not crs?.doi?
      check = API.use.crossref.reverse options.citation, undefined, true
      crs = check if check.doi and check.title? and check.title.length and (not metadata.year? or not check.year? or metadata.year is check.year) and (not metadata.journal? or not check.journal? or metadata.journal.toLowerCase().replace(/['".,\/\^&\*;:!\?#\$%{}=\-_`~()]/g,' ').replace(/\s{2,}/g,' ').trim() is check.journal.toLowerCase().replace(/['".,\/\^&\*;:!\?#\$%{}=\-_`~()]/g,' ').replace(/\s{2,}/g,' ').trim())
    _get.metadata(crs) if crs?
    if crs?.url? and crs.redirect isnt false and crs.licence? and crs.licence.indexOf('creativecommons') isnt -1
      res.url = crs.redirect ? crs.url
      res.found.crossref = res.url

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

  _get.citation = () ->
    a = 1 # if citation was provided by user, try to extract as much metadata as we can from it (does this count as user provided metadata?
    
  _get.permissions = () ->
    res.permissions ?= API.service.oab.permissions metadata, undefined, undefined, undefined, options.from

  _get.ill = () ->
    res.ill = {}
    try res.ill.terms = API.service.oab.ill.terms res.from
    try res.ill.openurl = API.service.oab.ill.openurl res.from, metadata
    try res.ill.subscription = API.service.oab.ill.subscription res.from, metadata, res.refresh

  # loop runner ================================================================
  _running = {}
  _run = (src, which) ->
    if not _running[src]
      res.checked.push(src) if src not in res.checked
      _running[src] = true
      if src in ['oabutton','reverse','bing','journal','content','scrape','citation','permissions','ill']
        try _get[src]()
      else
        try
          rs = false
          if src is 'oadoi' and which is 'doi' and metadata[which]?
            rs = API.use.oadoi.doi metadata.doi, true
          else if src is 'crossref' and which in ['doi','title']
            rs = API.use.crossref.works[which] metadata[which], true
            if which is 'doi' and not rs?.crossref_type
              res.doi_not_in_crossref = metadata.doi
              delete options.url if typeof options.url is 'string' and options.url.indexOf('doi.org/' + metadata.doi) isnt -1
              delete metadata.doi
              delete options.doi
          else if src is 'epmc' and which in ['doi','title','pmid','pmcid']
            rs = API.use.europepmc[if which is 'pmcid' then 'pmc' else which] metadata[which], true
          else if src is 'doaj' and which in ['doi','title']
            rs = API.use.doaj.articles[which] metadata[which]
          else if API.use[src]?[which]?
            # other possible sources to check title or doi are ['base','dissemin','share','core','openaire','fighsare'] 
            # but we do not use them by default any more
            rs = API.use[src][which] metadata[which]
          if typeof rs is 'object'
            mt = rs.title ? rs.dctitle ? rs.bibjson?.title ? rs.metadata?['oaf:result']?.title?.$
            if rs.url and (src isnt 'crossref' or (typeof rs.licence is 'string' and rs.licence.indexOf('creativecommons') isnt -1)) and (which isnt 'title' or (mt and mt.length <= metadata.title.length*1.2 and mt.length >= metadata.title.length*.8 and metadata.title.toLowerCase().replace(/ /g,'').indexOf(mt.toLowerCase().replace(' ','').replace(' ','').replace(' ','').split(' ')[0]) isnt -1))
              if rs.redirect isnt false
                res.redirect = if rs.redirect then rs.redirect else rs.url
                res.url = res.redirect
                res.found[src] ?= res.url
              _get.metadata rs
      delete _running[src]

  _prl = (src, which) -> Meteor.setTimeout (() -> _run src, which), 1
  used = []
  _checked_title = []
  _checked_doi = []
  stop = false
  while not stop and not _got()
    _searchable_title = typeof metadata.title is 'string' and metadata.title.length > 8 and metadata.title.split(' ').length > 2
    # if options.citation and not yet tried fuller extraction from it, start extract from it
    if content and _.isEmpty metadata
      _prl 'content'
    else if not metadata.doi and not metadata.title and not metadata.pmid and not metadata.pmcid and options.url and 'scrape' in res.sources and ('oabutton' not in res.sources or 'oabutton' in res.checked)
      _prl 'scrape'
    if not catalogued? and 'oabutton' in res.sources
      more = false
      for tid in ['doi','title','pmid','pmcid','url']
        if metadata[tid] and tid not in used
          more = true
          used.push tid
      _prl('oabutton') if more
    # for each item in sources, if still not got and not url, and not cached, and have the necessary metadata to execute, and have not yet done it, then do it
    for src in res.sources
      if src is 'reverse'
        _prl('reverse') if 'reverse' not in res.checked and (metadata.title or options.citation) and (not metadata.doi or 'crossref' in _checked_doi) and (not metadata.title or 'crossref' in _checked_title) and not options.reversed
      else if src is 'bing'
        _prl('bing') if src not in res.checked and options.bing and not metadata.doi and not metadata.pmid and not metadata.pmcid and not options.url and not content and _searchable_title
      else if metadata.doi? and src not in _checked_doi
        _checked_doi.push src
        _prl src, 'doi'
      else if (metadata.pmid or metadata.pmcid) and src is 'epmc' and (not metadata.doi or src not in res.checked)
        _prl src, 'title'
      else if _searchable_title and src not in _checked_title
        _checked_title.push src
        _prl src, 'title'
      if (metadata.journal or metadata.issn) and src is 'doaj' and res.find and not res.url and res.checked.length > 1 and 'journal' not in res.checked
        _prl 'journal'

    _prl('permissions') if metadata.doi and options.permissions and 'permissions' not in res.checked
    _prl('ill') if options.ill and (metadata.doi or metadata.title) and 'ill' not in res.checked
    
    stop = _.isEmpty _running
    future = new Future()
    Meteor.setTimeout (() -> future.return()), 100
    future.wait()

  # processing done, save and return ===========================================
  
  # update or create a catalogue record, and a find record, without waiting
  _save = (id, data, fnd) ->
    if data? and not _.isEmpty data
      if id
        oab_catalogue.update id, data
      else
        fnd.catalogue = oab_catalogue.insert data
    oab_find.insert fnd
  _sv = (id, data, fnd) -> Meteor.setTimeout (() -> _save(id, data, fnd)), 1

  metadata.url ?= []
  metadata.url = [metadata.url] if typeof metadata.url is 'string'
  if catalogued?.metadata?.url?
    for cu in (if typeof catalogued.metadata.url is 'string' then [catalogued.metadata.url] else catalogued.metadata.url)
      metadata.url.push(cu) if cu not in metadata.url
  metadata.url.push(options.url) if typeof options.url is 'string' and options.url not in metadata.url
  metadata.url.push(res.url) if typeof res.url is 'string' and res.url not in metadata.url
  res.metadata = metadata

  delete res.url if res.url is false # we put url to the top of the response for humans using false, but remove that before saving
  res.uid = options.uid if options.uid
  res.username = options.username if options.username
  res.email = options.email if options.email
  res.started = started
  res.ended = Date.now()
  res.took = res.ended - res.started

  if JSON.stringify(metadata) isnt '{}' and res.test isnt true
    res.url = res.url[0] if _.isArray res.url
    if catalogued?
      upd = {}
      upd.url = res.url if res.url? and res.url isnt catalogued.url
      upd.metadata = metadata if not _.isEqual metadata, catalogued.metadata
      upd.sources = _.union(res.sources, catalogued.sources) if JSON.stringify(res.sources.sort()) isnt JSON.stringify catalogued.sources.sort()
      uc = _.union res.checked, catalogued.checked
      upd.checked = uc if JSON.stringify(uc.sort()) isnt JSON.stringify catalogued.checked.sort()
      uf = _.extend(res.found, catalogued.found)
      upd.found = uf if not _.isEqual uf, catalogued.found
      upd.permissions = res.permissions if res.permissions? and (not catalogued.permissions? or not _.isEqual res.permissions, catalogued.permissions) and not res.permissions.error?
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
'''