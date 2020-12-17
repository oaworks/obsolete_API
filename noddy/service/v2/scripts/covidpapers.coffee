
'''
import fs from 'fs'

API.add 'service/oab/scripts/covidpapers',
  csv: true
  get: 
    action: () ->
      res = []
      covid_paper.each 'NOT fulltext:* AND NOT pdf:* AND NOT metadata.licence:*creativecommons* AND NOT metadata.licence:*cc*', (rec) ->
        r = {}
        r.src = rec.src.join ','
        for m of rec.metadata
          if m is 'author'
            r.author = ''
            for a in rec.metadata.author
              if a.name
                r.author += ',' if r.author isnt ''
                r.author += a.name
          else if typeof rec.metadata[m] isnt 'string'
            try r[m] = rec.metadata[m].join ','
          else if m not in ['abstract']
            r[m] = rec.metadata[m]
        if r.doi
          try
            pr = API.service.oab.permission doi: r.doi
            r.archiving_allowed = pr?.best_permission?.can_archive ? 'unknown'
            r.version_allowed = pr?.best_permission?.version ? 'unknown'
        res.push r
      fs.writeFileSync '/home/cloo/static/covidpapers.csv', API.convert.json2csv res
      return res
'''
#scrap corresponding author emails...