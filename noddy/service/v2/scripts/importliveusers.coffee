'''
import fs from 'fs'

API.add 'service/oab/scripts/importliveusers',
  get: 
    roleRequired: 'root'
    action: () ->
      
      processed = 0
      bad = 0
      users = []
      loaded = 0
      
      #Users.remove '*', undefined, false

      _process = (rec) ->
        if users.length is 300
          loaded += 300
          #Users.import users, undefined, false
          users = []
          
        processed += 1
        if JSON.stringify(rec).indexOf('function') isnt -1
          bad += 1
        else
          delete rec.query if rec.query?
          delete rec.devices if rec.devices?
          if rec.service?.openaccessbutton?.ill?.config?
            if rec.service.openaccessbutton.ill.config.pilot?
              if rec.service.openaccessbutton.ill.config.pilot is true
                rec.service.openaccessbutton.ill.config.pilot = Date.now()
              else
                delete rec.service.openaccessbutton.ill.config.pilot
            if rec.service.openaccessbutton.ill.config.live?
              if rec.service.openaccessbutton.ill.config.live is true
                rec.service.openaccessbutton.ill.config.live = Date.now()
              else
                delete rec.service.openaccessbutton.ill.config.live
          if rec.service?.openaccessbutton?.deposit?.config?
            if rec.service.openaccessbutton.deposit.config.pilot?
              if rec.service.openaccessbutton.deposit.config.pilot is true
                rec.service.openaccessbutton.deposit.config.pilot = Date.now()
              else
                delete rec.service.openaccessbutton.deposit.config.pilot
            if rec.service.openaccessbutton.deposit.config.live?
              if rec.service.openaccessbutton.deposit.config.live is true
                rec.service.openaccessbutton.deposit.config.live = Date.now()
              else
                delete rec.service.openaccessbutton.deposit.config.live
          users.push rec


      res = JSON.parse fs.readFileSync '/home/cloo/backups/noddy_users_02042020.json'
      recs = res.hits.hits
      console.log recs.length
      
      for r in recs
        rec = r._source
        _process rec

      if users.length
        loaded += users.length
        #Users.import users, undefined, false
        users = []

      console.log processed, bad, loaded
      return loaded
'''

