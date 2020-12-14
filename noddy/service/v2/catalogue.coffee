
# DOIboost dataset may be useful too:
# https://zenodo.org/record/3559699

# TODO change this to become proper part of OAB stack

import unidecode from 'unidecode'

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
  get: 
    roleRequired: if API.settings.dev then undefined else 'openaccessbutton.admin'
    action: () -> 
      Meteor.setTimeout (() => API.service.academic.journal.load this.queryParams.sources, this.queryParams.refresh, this.queryParams.doajrefresh, this.queryParams.titles), 1
      return true
API.add 'service/academic/journal/load/examples', 
  get: 
    roleRequired: if API.settings.dev then undefined else 'openaccessbutton.admin'
    action: () -> 
      Meteor.setTimeout (() => API.service.academic.journal.load.examples()), 1
      return true
API.add 'service/academic/journal/load_oa', 
  get: 
    roleRequired: if API.settings.dev then undefined else 'openaccessbutton.admin'
    action: () -> 
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
  get: 
    roleRequired: if API.settings.dev then undefined else 'openaccessbutton.admin'
    action: () -> 
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
  ]}}}}, size: size, _source: {includes: ['label','snaks.property','snaks.value','snaks.qid']}}
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
      if rc.id and rc.country
        break
      else
        rc.id = s.value if s.property is 'P6782'
        if s.property is 'P17' and cwd = wikidata_record.get s.qid
          rc.country = cwd.label
    if str
      if rec._source.label.toLowerCase().indexOf('universit') isnt -1
        unis.push rc
      else if API.service.academic._clean(rec._source.label).replace('the ','').replace('university ','').replace('of ','').startsWith(str.replace('the ','').replace('university ','').replace('of ',''))
        starts.push rc
      else if str.indexOf(' ') is -1 or unidecode(str) isnt str # allow matches on more random characters that may be matching elsewhere in the data but not in the actual title
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
API.service.academic.journal.suggest = (str, from, size=100) ->
  q = {query: {filtered: {query: {query_string: {query: 'issn:* AND NOT dois:0'}}, filter: {bool: {should: []}}}}, size: size, _source: {includes: ['title','issn','publisher','src']}}
  q.from = from if from?
  if str
    if str.indexOf(' ') is -1
      if str.indexOf('-') isnt -1 and str.length is 9
        q.query.filtered.query.query_string.query = 'issn.exact:"' + str + '"'
      else
        if str.indexOf('-') isnt -1
          q.query.filtered.query.query_string.query = '(issn:"' + str.replace('-','" AND issn:') + '*)'
        else
          q.query.filtered.query.query_string.query = 'issn:' + str + '*'
        q.query.filtered.query.query_string.query += ' OR title:"' + str + '" OR title:' + str + '* OR title:' + str + '~'
    else
      str = API.service.academic._clean str
      q.query.filtered.query.query_string.query = 'issn:* AND NOT dois:0 AND (title:"' + str + '" OR '
      q.query.filtered.query.query_string.query += (if str.indexOf(' ') is -1 then 'title:' + str + '*' else '(title:' + str.replace(/ /g,'~ AND title:') + '*)') + ')'
  res = academic_journal.search q
  starts = []
  extra = []
  for rec in res?.hits?.hits ? []
    if not str or JSON.stringify(rec._source.issn).indexOf(str) isnt -1 or API.service.academic._clean(rec._source.title).startsWith(str)
      starts.push rec._source
    else
      extra.push rec._source
    rec._source.id = rec._source.issn[0]
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
              cr = API.use.crossref.journals.doi isn
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
      



API.service.academic.journal.load = (sources) ->
  if sources
    sources = sources.split(',') if typeof sources is 'string'
  else
    # if no sources specified, dump everything and load fresh
    academic_journal.remove '*' # could make this a bulk delete earlier than createdAt now

  processed = 0
  saved = 0
  batch = []
  loadedissns = []

  _load = (rec={}) ->
    processed += 1
    console.log processed, saved, batch.length, loadedissns.length
    if batch.length >= 10000
      academic_journal.insert batch
      batch = []

    journal = {}

    # example crossref record https://dev.api.cottagelabs.com/use/crossref/journals/0965-2302
    if rec?.ISSN? and rec.ISSN.length # crossref uses capitalised journal ISSN list
      journal.title = rec.title
      journal.publisher = rec.publisher
      journal.subject = rec.subjects # objects with name and ASJC code
      journal.issn = _.uniq rec.ISSN # crossref can have duplicates in it...
      journal.doi = rec.doi # an example DOI inserted to crossref records, if we were able to find one
      journal.dois = rec.counts?.total-dois
      if rec.breakdowns?['dois-by-issued-year']?
        journal.years = []
        for yr in rec.breakdowns['dois-by-issued-year']
          journal.years.push(yr[0]) if yr.length is 2 and yr[0] not in journal.years
        journal.years.sort()
      journal.issn = [journal.issn] if typeof journal.issn is 'string'
      journal.src = ['crossref']
      try rec = wikidata_record.find '(snaks.value.exact:"' + journal.issn.join('" OR snaks.value.exact:"') + '") AND snaks.key.exact:"ISSN" AND snaks.key.exact:"instance of" AND snaks.qid.exact:"Q5633421"'

    if rec?.snaks
      for snak in rec.snaks
        if snak.property is 'P921'
          journal.subject ?= []
          if snak.value
            journal.subject.push {name: snak.value}
          else
            sb = wikidata_record.get snak.qid # remove this if too slow
            journal.subject.push({name: sb.label}) if sb?.label?
        if snak.key is 'ISSN' and not journal.issn 
          # don't trust wikidata ISSNs if we already have crossref ones. but note this means we will miss some matches where crossref is wrong and not wikidata
          # here is one where crossref is wrong and we could get the right one from wikidata: https://dev.api.cottagelabs.com/use/crossref/journals?q="1474-9728"
          # crossref wrongly has the incorrect ISSN and one other, wheras wikidata has the two correct ones
          # but then wikidata can be wrong and get us more wrong stuff, like: https://dev.lvatn.com/use/wikidata?q="1684-1182"
          # it has the wrong ISSN 0253-2662. The proper alternative is 1995-9133
          journal.issn ?= []
          snv = snak.value.toUpperCase().trim()
          journal.issn.push(snv) if snv not in journal.issn
        if snak.key is 'publisher'
          try journal.publisher ?= wikidata_record.get(snak.qid).label
        if snak.property is 'P5115'
          journal.wikidata_in_doaj = snak.value
          journal.is_oa = true
        if snak.property is 'P275'
          try journal.licence ?= wikidata_record.get(snak.qid).label
      journal.src ?= []
      journal.src.push 'wikidata'
      journal.title = rec.label
      journal.wikidata = rec.id

    if not rec?.bibjson? and journal.issn? and journal.issn.length
      rec = doaj_journal.find 'bibjson.pissn.exact:"' + journal.issn.join('" OR bibjson.pissn.exact:"') + '" OR bibjson.eissn.exact:"' + journal.issn.join('" OR bibjson.eissn.exact:"') + '"'
    if rec?.bibjson?
      journal.src ?= []
      journal.src.push 'doaj'
      journal.is_oa = true
      journal.doaj_admin = rec.admin if rec.admin?
      journal.title ?= rec.bibjson.title
      journal.publisher ?= rec.bibjson.publisher
      journal.keyword ?= rec.bibjson.keywords
      if rec.bibjson.subject? and rec.bibjson.subject.length
        journal.subject ?= []
        for jsn in rec.bibjson.subject
          jsn.name ?= jsn.term # doaj has the subject "name" in the "term" key
          journal.subject.push jsn
      journal.issn ?= []
      journal.issn.push(rec.bibjson.pissn) if rec.bibjson.pissn? and rec.bibjson.pissn not in journal.issn
      journal.issn.push(rec.bibjson.eissn) if rec.bibjson.eissn? and rec.bibjson.eissn not in journal.issn
      try journal.licence = rec.bibjson.license[0].title.toLowerCase().replace(/ /g, '-')
    
    if journal.issn? and journal.issn.length
      saved += 1
      for issn in journal.issn
        loadedissns.push(issn) if issn not in loadedissns
      batch.push journal

  # start with everything in crossref
  if not sources or 'crossref' in sources
    crossref_journal.each '*', (rec) ->
      _load(rec) if not sources or ('crossref' in sources and not academic_journal.find 'issn.exact:"' + rec.ISSN.join('" OR issn.exact:"') + '"')

  if not sources or 'wikidata' in sources
    console.log 'academic journal import trying remainders in wikidata'
    wikidata_record.each 'snaks.key.exact:"ISSN" AND snaks.key.exact:"instance of" AND snaks.qid.exact:"Q5633421"', (rec) ->
      loadable = true
      issns = []
      for snak in rec.snaks
        if snak.key.indexOf('ISSN') is 0 # could be ISSN-L for example
          svn = snak.value.toUpperCase().trim()
          issns.push svn
          if svn in loadedissns
            loadable = false
            break
      _load(rec) if loadable and (not sources or ('wikidata' in sources and not academic_journal.find 'issn.exact:"' + issns.join('" OR issn.exact:"') + '"'))

  if not sources or 'doaj' in sources
    console.log 'academic journal import trying remainders in doaj'
    doaj_journal.each '*', (rec) ->
      loadable = true
      issns = []
      for i in rec.bibjson?.identifier ? []
        if typeof i.id is 'string' and i.type.indexOf('issn') isnt -1
          isn = i.id.toUpperCase().trim()
          issns.push isn
          if isn in loadedissns
            loadable = false
            break
      _load(rec) if loadable and (not sources or ('doaj' in sources and not academic_journal.find 'issn.exact:"' + issns.join('" OR issn.exact:"') + '"'))

  academic_journal.insert(batch) if batch.length

  API.mail.send
    from: 'alert@cottagelabs.com'
    to: 'alert@cottagelabs.com'
    subject: 'Academic journal import complete' + (if API.settings.dev then ' (dev)' else '')
    text: 'processed ' + processed + ', saved ' + saved + ', ' + loadedissns.length + ' unique ISSNs'

  return saved

API.service.academic.journal.load.examples = () ->
  started = Date.now()
  tried = 0
  found = 0
  academic_journal.each 'NOT doi:*', (rec) ->
    console.log tried, found, (Date.now() - started)
    tried += 1
    rec.doi = API.use.crossref.journals.doi rec.issn
    if rec.doi?
      academic_journal.update rec._id, doi: rec.doi
      found += 1
  API.log 'finished looking for crossref journal DOI examples, took ' + (Date.now() - started)
  return found

_load_examples = () -> # remove this once we are closer to having them all, or have a full crossref index
  if API.settings.cluster?.ip? and API.status.ip() not in API.settings.cluster.ip
    API.service.academic.journal.load.examples()
#Meteor.setTimeout _load_examples, 6000


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