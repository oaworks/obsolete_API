
# DOIboost dataset may be useful too:
# https://zenodo.org/record/3559699

# TODO change this to become proper part of OAB stack

import fs from 'fs'
import Future from 'fibers/future'
import unidecode from 'unidecode'
import tar from 'tar'

API.service ?= {}
API.service.academic = {}

#@academic_catalogue = new API.collection {index:"academic",type:"catalogue"}
@academic_journal = new API.collection {index:"academic",type:"journal"}
#@academic_author = new API.collection {index:"academic",type:"author"}
#@academic_institution = new API.collection {index:"academic",type:"institution"}
#@academic_funder = new API.collection {index:"academic",type:"funder"}
@academic_publisher = new API.collection {index:"academic",type:"publisher"}

# TODO have academic catalogue track everything in oab catalogue and copy it, or query it too

#API.add 'service/academic/open', () -> return academic_catalogue.search this, {restrict:[{exists: {field:'url'}}]}
#API.add 'service/academic/catalogue', () -> return academic_catalogue.search this
#API.add 'service/academic/catalogue/:cid', get: () -> return academic_catalogue.get this.urlParams.cid

API.add 'service/academic/catalogue/:doi/:doi2', get: () -> return API.service.academic.article.doi this.urlParams.doi + '/' + this.urlParams.doi2
API.add 'service/academic/catalogue/:doi/:doi2/:doi3', get: () -> return API.service.academic.article.doi this.urlParams.doi + '/' + this.urlParams.doi2 + '/' + this.urlParams.doi3

API.add 'service/academic/article/suggest', get: () -> return API.service.academic.article.suggest undefined, this.queryParams.from
API.add 'service/academic/article/suggest/:ac', get: () -> return API.service.academic.article.suggest this.urlParams.ac

API.add 'service/academic/journal', () -> return academic_journal.search this
API.add 'service/academic/journal/:jid', 
  get: 
    () -> 
      if gt = academic_journal.get this.urlParams.jid
        return gt
      else if igt = academic_journal.find 'issn.exact:"' + this.urlParams.jid + '"'
        return igt
      else
        return 404
API.add 'service/academic/journal/:jid/oa', get: () -> return API.service.academic.journal.is_oa this.urlParams.jid, this.queryParams.doi
API.add 'service/academic/journal/suggest', get: () -> return API.service.academic.journal.suggest undefined, this.queryParams.from
API.add 'service/academic/journal/suggest/:ac', get: () -> return API.service.academic.journal.suggest this.urlParams.ac
API.add 'service/academic/journal/load', 
  get: () -> 
    Meteor.setTimeout (() => API.service.academic.journal.load this.queryParams.sources, this.queryParams.refresh, this.queryParams.doajrefresh, this.queryParams.titles), 1
    return true
API.add 'service/academic/journal/load_oa', 
  get: () -> 
    Meteor.setTimeout (() => API.service.academic.journal.load_oa this.queryParams.refresh), 1
    return true

#API.add 'service/academic/funder', () -> return academic_funder.search this
#API.add 'service/academic/funder/:jid', get: () -> return academic_funder.get this.urlParams.jid
API.add 'service/academic/funder/suggest', get: () -> return API.service.academic.funder.suggest undefined, this.queryParams.from
API.add 'service/academic/funder/suggest/:ac', get: () -> return API.service.academic.funder.suggest this.urlParams.ac

#API.add 'service/academic/institution', () -> return academic_institution.search this
#API.add 'service/academic/institution/:jid', get: () -> return academic_institution.get this.urlParams.jid
API.add 'service/academic/institution/suggest', get: () -> return API.service.academic.institution.suggest undefined, this.queryParams.from
API.add 'service/academic/institution/suggest/:ac', get: () -> return API.service.academic.institution.suggest this.urlParams.ac

API.add 'service/academic/publisher', () -> return academic_publisher.search this
API.add 'service/academic/publisher/:jid', get: () -> return academic_publisher.get this.urlParams.jid
#API.add 'service/academic/publisher/suggest', get: () -> return API.service.academic.publisher.suggest undefined, this.queryParams.from
#API.add 'service/academic/publisher/suggest/:ac', get: () -> return API.service.academic.publisher.suggest this.urlParams.ac
#API.add 'service/academic/publisher/load', get: () -> return API.service.academic.publisher.load this.queryParams.sources
API.add 'service/academic/publisher/load_oa', 
  get: () -> 
    Meteor.setTimeout (() => API.service.academic.publisher.load_oa this.queryParams.refresh), 1
    return true



API.service.academic._clean = (str) ->
  # .replace(/[^a-z0-9 ]/g,'')
  # return unidecode(str.toLowerCase()).replace(/\-/g,' ').replace(/ +/g,' ').trim()
  # unicode P replacer string from https://stackoverflow.com/questions/4328500/how-can-i-strip-all-punctuation-from-a-string-in-javascript-using-regex
  #str = str.replace(/\-/g,' ')
  pure = /[!-/:-@[-`{-~¡-©«-¬®-±´¶-¸»¿×÷˂-˅˒-˟˥-˫˭˯-˿͵;΄-΅·϶҂՚-՟։-֊־׀׃׆׳-״؆-؏؛؞-؟٪-٭۔۩۽-۾܀-܍߶-߹।-॥॰৲-৳৺૱୰௳-௺౿ೱ-ೲ൹෴฿๏๚-๛༁-༗༚-༟༴༶༸༺-༽྅྾-࿅࿇-࿌࿎-࿔၊-၏႞-႟჻፠-፨᎐-᎙᙭-᙮᚛-᚜᛫-᛭᜵-᜶។-៖៘-៛᠀-᠊᥀᥄-᥅᧞-᧿᨞-᨟᭚-᭪᭴-᭼᰻-᰿᱾-᱿᾽᾿-῁῍-῏῝-῟῭-`´-῾\u2000-\u206e⁺-⁾₊-₎₠-₵℀-℁℃-℆℈-℉℔№-℘℞-℣℥℧℩℮℺-℻⅀-⅄⅊-⅍⅏←-⏧␀-␦⑀-⑊⒜-ⓩ─-⚝⚠-⚼⛀-⛃✁-✄✆-✉✌-✧✩-❋❍❏-❒❖❘-❞❡-❵➔➘-➯➱-➾⟀-⟊⟌⟐-⭌⭐-⭔⳥-⳪⳹-⳼⳾-⳿⸀-\u2e7e⺀-⺙⺛-⻳⼀-⿕⿰-⿻\u3000-〿゛-゜゠・㆐-㆑㆖-㆟㇀-㇣㈀-㈞㈪-㉃㉐㉠-㉿㊊-㊰㋀-㋾㌀-㏿䷀-䷿꒐-꓆꘍-꘏꙳꙾꜀-꜖꜠-꜡꞉-꞊꠨-꠫꡴-꡷꣎-꣏꤮-꤯꥟꩜-꩟﬩﴾-﴿﷼-﷽︐-︙︰-﹒﹔-﹦﹨-﹫！-／：-＠［-｀｛-･￠-￦￨-￮￼-�]|\ud800[\udd00-\udd02\udd37-\udd3f\udd79-\udd89\udd90-\udd9b\uddd0-\uddfc\udf9f\udfd0]|\ud802[\udd1f\udd3f\ude50-\ude58]|\ud809[\udc00-\udc7e]|\ud834[\udc00-\udcf5\udd00-\udd26\udd29-\udd64\udd6a-\udd6c\udd83-\udd84\udd8c-\udda9\uddae-\udddd\ude00-\ude41\ude45\udf00-\udf56]|\ud835[\udec1\udedb\udefb\udf15\udf35\udf4f\udf6f\udf89\udfa9\udfc3]|\ud83c[\udc00-\udc2b\udc30-\udc93]/g;
  str = str.replace(pure, ' ')
  return str.toLowerCase().replace(/ +/g,' ').trim()

API.service.academic.article = {}
API.service.academic.article.suggest = (str, from, size=100) ->
  q = {query: {filtered: {query: {}, filter: {bool: {must: [
    {term: {'snaks.property.exact':'P356'}} # things with a DOI, about 22million
  ], must_not: [
    {term: {'snaks.property.exact':'P236'}} # ISSN - some journals have been given a DOI but they are journal, not article - only removes about 50k
  ]}}}}, size: size, _source: {includes: ['label','snaks.property','snaks.value']}}
  q.from = from if from?
  if str
    str = API.service.academic._clean str
    q.query.filtered.query.query_string = {query: 'label:' + str.replace(/ /g,' AND label:') + '*'}
  else
    q.query.filtered.query.match_all = {}
  res = wikidata_record.search q
  starts = []
  extra = []
  for rec in res?.hits?.hits ? []
    rc = {title: rec._source.label}
    for s in rec._source.snaks
      if s.property is 'P356'
        rc.doi = s.value
        break
    if str and API.service.academic._clean(rc.title).startsWith(str)
      starts.push rc
    else
      extra.push rc
  return total: res?.hits?.total ? 0, data: _.union starts.sort((a, b) -> return a.title.length - b.title.length), extra.sort((a, b) -> return a.title.length - b.title.length)

API.service.academic.article.doi = (doi) ->
  q = {query: {filtered: {query: {}, filter: {bool: {must: [
    {term: {'snaks.property.exact':'P356'}} # things with a DOI, about 22million
    {term: {'snaks.value.exact':doi}}
  ]}}}}}
  res = wikidata_record.search q
  if res?.hits?.hits? and res.hits.hits.length
    rec = res.hits.hits[0]._source # format this
    update = false
    rn = {}
    rn.wikidata = rec._id
    rn.doi = doi
    rn.title = rec.label
    issns = false
    for snak in rec.snaks ? []
      if snak.qid and not snak.value
        qs = API.use.wikidata.get snak.qid
        if qs?.label?
          update = true
          snak.value = qs.label
          if snak.qid is 'P1433'
            for js in qs.snaks
              if js.property is 'P236' and js.value
                rn.issn ?= []
                jsv = js.value.toUpperCase().trim()
                rn.issn.push(jsv) if jsv not in rn.issn
      rn.licence = snak.value if snak.value and snak.property is 'P275'
      if snak.value and snak.property is 'P236'
        issns = true
        rn.issn ?= []
        snv = snak.value.toUpperCase().trim()
        rn.issn.push(snv) if snv not in rn.issn
      if snak.value and snak.property is 'P921'
        rn.subject ?= []
        rn.subject.push(snak.value) if snak.value not in rn.subject
      if snak.value and snak.property is 'P6216'
        rn.copyright ?= []
        rn.copyright.push(snak.value) if snak.value not in rn.copyright
      rn.issue = snak.value if snak.value and snak.property is 'P433'
      rn.volume = snak.value if snak.value and snak.property is 'P478'
      rn.page = snak.value if snak.value and snak.property is 'P304'
      rn.pmcid = snak.value if snak.value and snak.property is 'P932'
      rn.pmid = snak.value if snak.value and snak.property is 'P698'
      rn.journal = snak.value if snak.value and snak.property is 'P1433'
      if snak.value and snak.property in ['P50','P2093']
        rn.author ?= []
        rn.author.push name: snak.value
    if rn.journal and not rn.issn?
      fj = academic_journal.search 'issn:* AND title:' + rn.journal.replace(/ /g,' AND title:') + '*'
      if fj?.hits?.total is 1
        rn.issn = fj.hits.hits[0]._source.issn
    rn.issn = [rn.issn] if typeof rn.issn is 'string'
    if rn.issn? and not issns
      for isn in rn.issn
        rec.snaks.push property: 'P236', key: 'ISSN', value: isn
    if update
      wikidata_record.update rec._id, snaks: rec.snaks
    return rn
  else
    return false

API.service.academic.institution = {}
API.service.academic.institution.suggest = (str, from, size=100) ->
  # for now just query wikidata, but later can build this to query wikidata and other sources, plus a sheet
  # and merge them into the academic_funder collection, and query from that - NOTE terms query was too big here, so using a search then filtering the results
  q = {query: {filtered: {query: {}, filter: {bool: {should: [
    {term: {'snaks.property.exact':'P6782'}} # ROR ID
    #{term: {'snaks.property.exact':'P2427'}} #, # GRID ID TODO should we only accept institutions with GRID IDs?
    #{term: {'snaks.property.exact':'P5586'}}, # Times higher education world university ID
    #{term: {'snaks.property.exact':'P5584'}}, # QS world university ID
    #{term: {'snaks.qid.exact':'Q4671277'}} #instance of academic institution
  ]}}}}, size: size, _source: {includes: ['label','snaks.property','snaks.value']}}
  q.from = from if from?
  if str
    str = API.service.academic._clean(str).replace(/the /gi,'')
    q.query.filtered.query.query_string = {query: (if str.indexOf(' ') is -1 then 'snaks.value.exact:"' + str + '" OR ' else '') + '(label:' + str.replace(/ /g,' AND label:') + '*) OR snaks.value:"' + str + '" OR description:"' + str + '"'}
  else
    q.query.filtered.query.match_all = {}
  res = wikidata_record.search q
  unis = []
  starts = []
  extra = []
  for rec in res?.hits?.hits ? []
    rc = {title: rec._source.label}
    for s in rec._source.snaks
      if s.property is 'P6782'
        rc.id = s.value
        break
    if str
      if rec._source.label.toLowerCase().indexOf('universit') isnt -1
        unis.push rc
      else if API.service.academic._clean(rec._source.label).replace('the ','').replace('university ','').replace('of ','').startsWith(str.replace('the ','').replace('university ','').replace('of ',''))
        starts.push rc
      else if unidecode(str) isnt str # allow matches on more random characters that may be matching elsewhere in the data but not in the actual title
        extra.push rc
    else
      extra.push rc
  return total: res?.hits?.total ? 0, data: _.union unis.sort((a, b) -> return a.title.length - b.title.length), starts.sort((a, b) -> return a.title.length - b.title.length), extra.sort((a, b) -> return a.title.length - b.title.length)

API.service.academic.funder = {}
API.service.academic.funder.suggest = (str, from, size=100) ->
  # for now just query wikidata, but later can build this to query wikidata and other sources, plus a sheet
  # and merge them into the academic_funder collection, and query from that - NOTE terms query was too big here, so using a search then filtering the results
  q = {query: {filtered: {query: {}, filter: {bool: {should: [
    {term: {'snaks.property.exact':'P3153'}} #, # crossref funder ID - TODO should we only accept crossref funders?
    # NOTE we are only pulling from wikidata here so far, for demo, which has about 13k funders with crossref funder IDs, whereas crossref actually has about 25k
    # pulling all in from crossref is not hard though, just not done yet (see journal merges and pulls from multiple sources below)
    #{term: {'snaks.property.exact':'P3500'}}, # ringgold ID
    #{term: {'snaks.property.exact':'P6782'}}, # ROR ID
    #{term: {'snaks.qid.exact':'Q372353'}}, # instance of research funding
    #{term: {'snaks.qid.exact':'Q45759536'}} # member of open research funders group
  ]}}}}, size: size, _source: {includes: ['label','snaks.property','snaks.value']}}
  q.from = from if from?
  if str
    str = API.service.academic._clean str
    q.query.filtered.query.query_string = {query: 'label:' + str.replace(/ /g,' AND label:') + '*'}
  else
    q.query.filtered.query.match_all = {}
  res = wikidata_record.search q
  starts = []
  extra = []
  for rec in res?.hits?.hits ? []
    rc = {title: rec._source.label}
    for s in rec._source.snaks
      if s.property is 'P3153'
        rc.id = s.value
        break
    if not str or API.service.academic._clean(rec._source.label).startsWith(str)
      starts.push rc #rec._source.label
    else
      extra.push rc #rec._source.label
  return total: res?.hits?.total ? 0, data: _.union starts.sort((a, b) -> return a.title.length - b.title.length), extra.sort((a, b) -> return a.title.length - b.title.length)

API.service.academic.journal = {}
API.service.academic.journal.suggest = (str, from, size=100, isnumber) ->
  q = {query: {filtered: {query: {query_string: {}}, filter: {bool: {should: []}}}}, size: size, _source: {includes: ['title','issn','publisher','src']}}
  q.from = from if from?
  if str
    # only ones with ISSN for now? and only ones in crossref?
    if isnumber isnt false and (typeof str is 'number' or not isNaN parseInt str.replace('-','').replace(/ /g,''))
      isnumber = true
      isnr = if typeof str is 'number' then str else str.replace(' ','-')
      if isnr.length is 9
        isnr = 'issn.exact:"' + isnr + '"'
      else if isnr.indexOf('-') isnt -1
        isnrp = isnr.split '-'
        isnr = 'issn:"' + isnrp[0] + '"'
        isnr += ' AND issn:' + isnrp[1] + '*' if isnrp[1].length
      else
        isnr = 'issn:' + isnr + '*'
      q.query.filtered.query.query_string.query = isnr
    else
      str = API.service.academic._clean str
      q.query.filtered.query.query_string.query = 'issn:* AND NOT counts.total-dois:0 AND (title:"' + str + '" OR '
      q.query.filtered.query.query_string.query += (if str.indexOf(' ') is -1 then 'title:' + str + '*' else '(title:' + str.replace(/ /g,' AND title:') + '*)') + ')'
  else
    q.query.filtered.query.query_string.query = 'issn:* AND NOT counts.total-dois:0'
  res = academic_journal.search q
  if isnumber and res?.hits?.total is 0 and str.replace(/[^0-9]/g,'').length
    return API.service.academic.journal.suggest str, from, size, false
  starts = []
  extra = []
  for rec in res?.hits?.hits ? []
    if rec._source.DisplayName?
      rec._source.title = rec._source.DisplayName # prefer MAG journal titles where available
      delete rec._source.DisplayName
    if isnumber
      for i in rec._source.issn
        if i.startsWith str
          extra.push rec._source
          break
    else if not str or API.service.academic._clean(rec._source.title).startsWith(str)
      starts.push rec._source
    else
      extra.push rec._source
    rec._source.id = rec._source.issn[0]
    rec._source.doaj = true if 'doaj' in rec._source.src
    #delete rec._source.issn
    #delete rec._source.src
  return total: res?.hits?.total ? 0, data: _.union starts.sort((a, b) -> return a.title.length - b.title.length), extra.sort((a, b) -> return a.title.length - b.title.length)


API.service.academic.journal.is_oa = (issns, doi) ->
  issns = [issns] if typeof issns is 'string'
  foundfalse = false
  for i in academic_journal.fetch 'issn.exact:"' + issns.join('" OR issn.exact:"') + '"'
    if not i.is_oa?
      i = API.service.academic.journal.load_oa undefined, i, doi
    if i?.is_oa
      return i
    else if i?.is_oa is false
      foundfalse = true
  return if foundfalse then false else undefined

API.service.academic.journal.load_oa = (refresh, issn_or_rec, doi) ->
  res = total: academic_journal.count(if refresh then '*' else 'NOT is_oa:*'), processed: 0, oa: 0
  _loadoa = (rec) ->
    res.processed += 1
    console.log res
    is_oa = false
    oadoi_is_oa = 0
    if 'doaj'in rec.src
      rec.is_oa = true
    else if false # decided not to use oadoi as a source of "openness" because it does not meet requirements yet
      issn = rec.issn ? rec.ISSN
      if issn?
        issn = [issn] if typeof issn is 'string'
        for isn in issn
          if not is_oa
            # check wikidata first because we have a local cache and checking crossref journals seems very slow
            adoi = doi ? false
            if adoi is false
              iw = wikidata_record.find '"' + isn + '" AND snaks.property.exact:"P356"'
              if iw?
                # got a record of an article containing the ISSN (may not have the ISSN as actual value, but could be in DOI or other meta)
                for s in iw.snaks
                  if s.key is 'DOI'
                    adoi = s.value
            if adoi is false
              iw = wikidata_record.find 'snaks.value.exact:"' + isn + '" AND snaks.property.exact:"P236"'
              if iw?
                # found a record that is a journal with the ISSN
                ww = wikidata_record.find 'snaks.qid.exact:"' + iw._id + '" AND snaks.property.exact:"P1433" AND snaks.property.exact:"P356"'
                if ww?
                  # found a record that is "published in" the record of the journal
                  for s in ww.snaks
                    if s.key is 'DOI'
                      adoi = s.value
            if adoi is false
              cr = API.use.crossref.journals.dois.example isn
              adoi = cr if cr?
            if adoi and oad = API.use.oadoi.doi adoi, false
              oadoi_is_oa = oad.journal_is_oa
              is_oa = if oadoi_is_oa then true else false
    res.oa += 1 if is_oa
    academic_journal.update rec._id, {is_oa: is_oa, oadoi_is_oa: (if oadoi_is_oa isnt 0 then oadoi_is_oa else undefined)}
    rec.is_oa = is_oa
    rec.oadoi_is_oa = oadoi_is_oa if oadoi_is_oa isnt 0
    return rec
  if typeof issn_or_rec is 'object'
    return _loadoa issn_or_rec
  else if typeof issn_or_rec is 'string' and r = academic_journal.find 'issn.exact:"' + issn_or_rec + '"'
    return _loadoa r
  else
    academic_journal.each (if refresh then '*' else 'NOT is_oa:*'), _loadoa
    return res
      
API.service.academic.journal.load = (sources=['wikidata','crossref','doaj'], refresh=false, doajrefresh=false, titles=false) -> # ,'microsoft','sheet'
  academic_journal.remove('*') if refresh is true
  sources = sources.split(',') if typeof sources is 'string'
  processed = 0
  saved = 0
  updated = 0
  batch = []
  _load = (rec) ->
    console.log processed, saved, updated, batch.length
    processed += 1
    journal = {}

    if batch.length >= 5000
      academic_journal.insert batch
      batch = []

    # example wikidata record https://dev.api.cottagelabs.com/use/wikidata/Q27721026
    if rec.snaks
      journal = rec # worth keeping full records?
      isjournal = false
      for snak in rec.snaks
        if snak.property is 'P921'
          sb = wikidata_record.get snak.qid
          if sb?.label?
            journal.subject ?= []
            journal.subject.push {name:sb.label}
        if snak.key is 'ISSN'
          journal.issn ?= []
          snv = snak.value.toUpperCase().trim()
          journal.issn.push(snv) if snv not in journal.issn
        if snak.key is 'publisher'
          try journal.publisher = wikidata_record.get(snak.qid).label
        if snak.property is 'P5115'
          journal.wikidata_in_doaj = snak.value
          journal.is_oa = true
        if snak.property is 'P275'
          try journal.licence = wikidata_record.get(snak.qid).label
        isjournal = true if snak.key is 'instance of' and snak.qid is 'Q5633421'
      if isjournal
        journal.src = ['wikidata']
        journal.title = rec.label
        journal.wikidata = rec.id
        delete journal._id
        delete journal.id
        delete journal.type
      else
        journal = {}
    
    # example crossref record https://dev.api.cottagelabs.com/use/crossref/journals/0965-2302
    else if rec.ISSN? # crossref uses capitalised journal ISSN list
      # crossref journal subjects is a list of object with keys name and ASJC (subjects and keywords handled below)
      journal = rec
      journal.src = ['crossref']
      journal.issn = journal.ISSN

    # example doaj record https://dev.api.cottagelabs.com/use/doaj/journals/issn/0124-2253
    else if rec.bibjson?
      journal = rec.bibjson
      journal.src = ['doaj']
      journal.is_oa = true
      journal.admin = rec.admin if rec.admin?
      journal.issn ?= []
      # handle keywords (list of keywords) and subject (list of objects)
      for i in journal.identifier ? []
        if typeof i.id is 'string'
          idv = i.id.toUpperCase().trim()
          if i.type.indexOf('issn') isnt -1 and idv not in journal.issn
            journal.issn.push idv
      if _.isArray(journal.license) and journal.license.length
        journal.licence = journal.license[0].title
    
    # example ms record https://dev.api.cottagelabs.com/use/microsoft/graph/journal/5bf573d51c5a1dcdd96ee6a8
    else if rec.DisplayName
      journal = rec
      journal.src = ['mag']
    
    # also want to get from a manually curated sheet source

    if not _.isEmpty journal
      if journal.subjects
        journal.subject = journal.subjects
        delete journal.subjects
      if journal.subject? and journal.subject.length
        sn = []
        for jsn in journal.subject
          if typeof journal.subject[0] is 'string'
            sn.push({name:jsn})
          else
            jsn.name ?= jsn.term # doaj has the subject "name" in the "term" key
            sn.push jsn
        journal.subject = sn
      if journal.keywords
        journal.keyword = journal.keywords
        delete journal.keywords
      if journal.keyword? and journal.keyword.length and typeof journal.keyword[0] isnt 'string'
        kn = []
        for ksn in journal.keyword
          kn.push(ksn.name ? ksn.term ? ksn.title ? ksn.value) if ksn.name? or ksn.term? or ksn.title? or ksn.value? # and anything else it could be in...
        journal.keyword = kn
      delete journal.createdAt
      delete journal.created_date
      delete journal.updatedAt
      delete journal.updated_date

      journal.issn = [journal.issn] if typeof journal.issn is 'string'
      journal.issn = _.uniq(journal.issn) if journal.issn? and journal.issn.length > 1
      if journal.issn? and journal.issn.length
        found = academic_journal.find 'issn.exact:"' + journal.issn.join('" OR issn.exact:"') + '"'
        if typeof found isnt 'object'
          batch.push journal
          saved += 1
        else
          upd = {}
          found.issn = [found.issn] if typeof found.issn is 'string'
          for k of journal
            if k in ['issn','title','publisher'] and journal.src[0] in ['crossref','doaj'] # allow crossref ISSN values to override others because for example Development has additional ISSNs in wikidata that should not be there
              if not _.isEqual journal[k], found[k]
                if journal.src[0] is 'crossref' or (journal.src[0] is 'doaj' and 'crossref' not in found.src)
                  upd[k] = journal[k]
                else if journal.src[0] is 'doaj' and k is 'issn'
                  upd[k] = _.clone found[k]
                  for j in journal[k]
                    upd[k].push(j) if j not in upd[k]
                  delete upd[k] if _.isEqual upd[k], found[k]
            else if not found[k]?
              upd[k] = journal[k]
            else if _.isArray journal[k]
              if not _.isArray found[k]
                upd[k] = journal[k]
              else if journal[k].length is 0 and found[k].length
                upd[k] = found[k]
              else
                if journal[k].length and typeof journal[k][0] is 'string'
                  upd[k] = _.union journal[k], found[k]
                else
                  try
                    if JSON.stringify(journal[k]).split('').sort().join('') isnt JSON.stringify(found[k]).split('').sort().join('')
                      upd[k] = journal[k]
                  catch
                    upd[k] = journal[k]
              delete upd[k] if _.isEqual upd[k], found[k]
            else if typeof found[k] is 'object'
              upd[k] = _.clone found[k]
              for kk of journal[k]
                upd[k][kk] ?= journal[k][kk]
              delete upd[k] if _.isEqual upd[k], found[k]
          if journal.wikidata_in_doaj and upd.issn?
            jwd = journal.wikidata_in_doaj.toUpperCase().trim() 
            if jwd not in upd.issn
              upd.issn.push jwd
          if not _.isEmpty upd
            academic_journal.update found._id, upd
            updated += 1

  if 'wikidata' in sources
    wikidata_record.each 'snaks.key.exact:"ISSN"', _load
    future = new Future() # wait a while for index to have everything saved, so that other sources dedup
    Meteor.setTimeout (() -> future.return()), 10000
    future.wait()

  if 'crossref' in sources
    crossref_journal.each '*', _load
    future = new Future()
    Meteor.setTimeout (() -> future.return()), 10000
    future.wait()

  if 'doaj' in sources
    try
      prev = false
      current = false
      fs.writeFileSync '/tmp/doaj' + (if API.settings.dev then '_dev' else ''), HTTP.call('GET', 'https://doaj.org/public-data-dump/journal', {npmRequestOptions:{encoding:null}}).content
      tar.extract file: '/tmp/doaj' + (if API.settings.dev then '_dev' else ''), cwd: '/tmp', sync: true # extracted doaj dump folders end 2020-10-01
      for f in fs.readdirSync '/tmp' # readdir alphasorts, so if more than one in tmp then last one will be newest
        if f.indexOf('doaj_journal_data') isnt -1
          if prev
            try fs.unlinkSync '/tmp/' + prev + '/journal_batch_1.json'
            try fs.rmdirSync '/tmp/' + prev
          prev = current
          current = f
      if current and (prev or refresh or doajrefresh) # if there was no prev, current download was same as last download so only load if forced refresh
        recs = JSON.parse fs.readFileSync '/tmp/' + current + '/journal_batch_1.json'
        _load(rec) for rec in recs
    future = new Future()
    Meteor.setTimeout (() -> future.return()), 10000
    future.wait()

  #if 'microsoft' in sources
  #  msgraph_journal.each '*', _load
  
  #if 'sheet'in sources

  if batch.length
    academic_journal.insert batch

  API.mail.send
    from: 'alert@cottagelabs.com'
    to: 'alert@cottagelabs.com'
    subject: 'Academic journal import complete'
    text: processed + ' ' + saved + ' ' + updated

  return saved



API.service.academic.publisher = {}
API.service.academic.publisher.load_oa = (refresh) ->
  res = total: academic_publisher.count(if refresh then '*' else 'NOT is_oa:*'), count: 0, searched: 0, matches: 0, oa: 0
  academic_publisher.each (if refresh then '*' else 'NOT is_oa:*'), (rec) ->
    res.count += 1
    console.log res
    is_oa = true
    qr = ''
    rec.names ?= []
    rec.names.push(rec.title) if rec.title not in rec.names
    for n in rec.names
      qr += ' OR ' if qr isnt ''
      qr += 'publisher.exact:"' + n + '"'
    journals = total: 0, open: 0, closed: 0
    try journals.expected = rec['counts-type'].all.journal
    if qr isnt ''
      res.searched += 1
      academic_journal.each qr, (jr) ->
        res.matches += 1 if journals.total is 0
        if jr.is_oa
          res.oa += 1 if journals.total is 0
          journals.open += 1
        else
          journals.closed += 1
        journals.total += 1
    academic_publisher.update rec._id, {is_oa: (journals.closed is 0), journals: journals}
  return res

API.service.academic.publisher.load = (sources=['crossref']) ->
  # TODO update this later to get publishers from wikidata, possibly other sources too
  sources = sources.split(',') if typeof sources is 'string'
  processed = 0
  saved = 0
  updated = 0
  duplicate = 0
  _load = (rec) ->
    console.log processed, saved, updated, duplicate
    processed += 1
    publisher = {}

    # example crossref record https://dev.api.cottagelabs.com/use/crossref/journals/0965-2302
    if rec?
      publisher = rec
      publisher.src = ['crossref']
      publisher._id = publisher.id
      publisher.title = publisher['primary-name']
      if publisher.location?
        publisher.address = publisher.location
        delete publisher.location

    if not _.isEmpty publisher
      delete publisher.createdAt
      delete publisher.created_date
      delete publisher.updatedAt
      delete publisher.updated_date

      if academic_publisher.get publisher._id
        duplicate += 1
      else
        srch = ''
        if publisher.title
          srch += ' OR ' if srch isnt ''
          srch += 'title:"' + publisher.title + '"'
        if srch isnt ''
          found = academic_publisher.find srch
          found = false if found and srch.title and srch.title.toLowerCase() isnt found.title.toLowerCase()
          if not found
            academic_publisher.insert publisher
            saved += 1
          else
            upd = {}
            for k of publisher
              if not found[k]?
                upd[k] = publisher[k]
              else if _.isArray publisher[k]
                upd[k] = if _.isArray(found[k]) then _.clone(found[k]) else if typeof found[k] is 'string' then [found[k]] else []
                for jk in publisher[k]
                  upd[k].push(jk) if typeof jk isnt 'string' or jk not in upd[k]
                delete upd[k] if found[k]? and _.isEqual upd[k], found[k]
              else if typeof found[k] is 'object'
                upd[k] = _.clone found[k]
                for kk of publisher[k]
                  upd[k][kk] ?= publisher[k][kk]
                delete upd[k] if _.isEqual upd[k], found[k]
            academic_publisher.update(found._id, upd) if not _.isEmpty upd
            updated += 1

  if 'crossref' in sources
    c_size = 1000
    c_counter = 0
    c_total = 0
    while c_total is 0 or c_counter < c_total
      crls = API.use.crossref.publishers.search undefined, c_counter, c_size
      c_total = crls.total if c_total is 0
      for crl in crls?.data ? []
        _load crl
      c_counter += c_size

  return saved