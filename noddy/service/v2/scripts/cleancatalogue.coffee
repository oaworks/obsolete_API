
'''API.add 'service/oab/scripts/cleancatalogue',
  get: 
    #roleRequired: 'root'
    action: () ->
      dev = if this.queryParams.live is true then false else true
      action = if this.queryParams.action? then true else false
      processed = 0
      fixed = 0

      _process = (rec) ->
        processed += 1
        if rec.url and _.isArray(rec.url) and rec.found?.epmc? and _.isArray rec.found.epmc
          upd = {}
          badu = false
          goodu = false
          for u in rec.url
            if u.indexOf('doi.org') is -1
              goodu = u
              break
            else
              badu = u
          if goodu
            upd.url = goodu
            upd.found = {epmc:goodu}
          else if badu
            if rec.metadata?.doi and action
              open = API.use.oadoi.doi rec.metadata.doi
              if open.url
                upd.url = open.url
                upd.found = {oadoi: rec.url}
          if rec.metadata?.url?
            if typeof rec.metadata.url is 'string' and rec.metadata.url is badu
              upd['metadata.url'] = '$DELETE'
            else if _.isArray rec.metadata.url and badu in rec.metadata.url
              upd['metadata.url'] = _.without rec.metadata.url, badu
          upd.found ?= {}
          upd.url ?= '$DELETE'
          fixed += 1
          oab_catalogue.update(rec._id, upd, undefined, undefined, undefined, undefined, dev) if action

      oab_catalogue.each 'url:* AND found.epmc:*', _process, undefined, undefined, undefined, undefined, dev

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'Catalogue fix complete'
        text: 'Recs processed: ' + processed + '\n\nRecs fixed: ' + fixed + '\n\nDev: ' + dev + '\n\nAction:' + action

      return dev: dev, action: action, processed: processed, fixed: fixed
'''


