'''
API.add 'service/oab/scripts/cleanusers',
  get: 
    #roleRequired: 'root'
    action: () ->
      dev = if this.queryParams.live is 'true' then false else true
      processed = 0
      old = 0
      never = 0
      bad = 0

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

      Users.each '*', _process, undefined, undefined, undefined, undefined, dev
      Users.remove '*', undefined, dev
      Users.import users, undefined, dev
  
      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'User fix complete'
        text: 'Users processed: ' + processed + '\n\nUsers found and kept: ' + users.length + '\n\nNever retrieved:' + never + '\n\nOld: ' + old + '\n\nBad: ' + bad

      return dev: dev, processed: processed, old: old, never: never, bad: bad, reload: users.length
'''



