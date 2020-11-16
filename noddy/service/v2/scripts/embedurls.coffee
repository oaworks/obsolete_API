
'''
import fs from 'fs'

API.add 'service/oab/scripts/embedurls',
  csv: true
  get: 
    action: () ->
      # note there are more users who may have used it on our setup pages but not 
      # run it remotely
      # https://api.openaccessbutton.org/finds?q=embedded:*%20AND%20(plugin:instantill%20OR%20plugin:shareyourpaper)&size=0&terms=from.exact
      fl = '/home/cloo/static/oabembedurls.json'
      if this.queryParams.refresh isnt true and fs.existsSync fl
        return JSON.parse fs.readFileSync(fl).toString()
      else
        dev = false
        urls = []
        emails = []
        ids = []
        res = []
        oab_find.each 'embedded:* AND from:* AND (plugin:instantill OR plugin:shareyourpaper)', ((rec) ->
          if typeof rec.embedded is 'string'
            url = rec.embedded.split('?')[0].split('#')[0].replace(/\/$/,'')
            url = url.split('://')[1] if url.indexOf('://') isnt -1
            if url not in urls
              save = true
              for c in ['shareyourpaper.org', 'josephmcarthur', 'openaccessbutton.org', 'instantill.org', 'cottagelabs.com', 'rscvd.org']
                if url.indexOf(c) isnt -1
                  save = false
                  break
              if save and typeof rec.from is 'string' and rec.from not in ids
                ids.push rec.from
                acc = Users.get rec.from, undefined, dev
                if acc?.email? or acc?.emails?
                  email = acc.email ? acc.emails[0].address
                  if email not in emails
                    emails.push email
                    urls.push url
                    res.push email: email, url: url, uid: rec.from
          ), undefined, undefined, undefined, undefined, dev
        console.log res.length
        fs.writeFileSync fl, JSON.stringify res, null, 2
        return res
'''