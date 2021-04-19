
API.add 'service/oab/scripts/useres',
  get: 
    action: () ->
      dev = if this.queryParams.live is true then false else true
      counter = 0
      cased = 0
      dups = 0
      _ck = (rec) ->
        counter += 1
        try
          eml = rec.email ? rec.emails[0].address
          cased += 1 if eml.toLowerCase() isnt eml
          dups += 1 if Users.count(undefined, 'email:"' + eml + '" OR emails.address:"' + eml + '"', dev) > 1
        console.log counter, cased, dups
      Users.each '*', undefined, _ck, undefined, undefined, undefined, dev
      return total: counter, cased: cased, duplicates: dups

'''API.add 'service/oab/scripts/cleanusers',
  get: 
    #roleRequired: 'root'
    action: () ->
      dev = if this.queryParams.live is true then false else true
      action = if this.queryParams.action? then true else false
      processed = 0
      fixed = 0

      _process = (rec) ->
        processed += 1
        upd = {}
        if rec.service?.openaccessbutton?.ill?.config?
          if rec.service.openaccessbutton.ill.config.pilot is '$DELETE'
            upd['service.openaccessbutton.ill.config.pilot'] = '$DELETE'
          if rec.service.openaccessbutton.ill.config.live is '$DELETE'
            upd['service.openaccessbutton.ill.config.live'] = '$DELETE'
            
        if rec.service?.openaccessbutton?.deposit?.config?
          if rec.service.openaccessbutton.deposit.config.pilot is '$DELETE'
            upd['service.openaccessbutton.deposit.config.pilot'] = '$DELETE'
          if rec.service.openaccessbutton.deposit.config.live is '$DELETE'
            upd['service.openaccessbutton.deposit.config.live'] = '$DELETE'
        if not _.isEmpty upd
          fixed += 1
          Users.update(rec._id, upd, undefined, undefined, undefined, undefined, dev) if action

      Users.each 'service.openaccessbutton.deposit.config.pilot:* OR service.openaccessbutton.deposit.config.live:* OR service.openaccessbutton.ill.config.pilot:* OR service.openaccessbutton.ill.config.live:*', _process, undefined, undefined, undefined, undefined, dev

      API.mail.send
        to: 'alert@cottagelabs.com'
        subject: 'User fix complete'
        text: 'Users processed: ' + processed + '\n\nUsers found and fixed: ' + fixed

      return dev: dev, action: action, processed: processed, fixed: fixed
'''



