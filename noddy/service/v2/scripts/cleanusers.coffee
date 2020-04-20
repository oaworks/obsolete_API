
'''API.add 'service/oab/scripts/cleanusers',
  get: 
    #roleRequired: 'root'
    action: () ->
      dev = if this.queryParams.live is 'true' then false else true
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



