'''
import fs from 'fs'

API.add 'service/oab/scripts/importdevusers',
  get: 
    roleRequired: 'root'
    action: () ->
      
      processed = 0
      bad = 0
      never = 0
      old = 0
      users = []
      
      _process = (rec) ->
        processed += 1
        if JSON.stringify(rec).indexOf('function') isnt -1
          bad += 1
        else if typeof rec.createdAt is 'string' or (not rec.retrievedAt? and rec.createdAt < 1514764800000) # start of 2018
          never += 1
        else if rec.retrievedAt < 1514764800000 # start of 2018
          old += 1
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


      res = JSON.parse fs.readFileSync '/home/cloo/backups/noddy_dev_users_02042020.json'
      recs = res.hits.hits
      console.log recs.length
      
      for r in recs
        rec = r._source
        _process rec

      #Users.remove '*'
      #Users.import users
      
      console.log users[0]

      return processed: processed, old: old, never: never, bad: bad, reload: users.length, users: users
'''

