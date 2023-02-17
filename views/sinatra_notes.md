### Reminder Notes for Sinatra ###
- Order matters : first route with a match is the one selected
- parameters in routes : /home/:name -> matches /home/brandi and /home/olivier
  - can access param via params hash -> params['name'] -> brandi
  - can also pass block parameter to represent parameters -> get /home/:name do |n|
                                                               puts n -> brandi
- can use regex in route matching
- optional parameter : /:optional?
- query parameters end up in params hash as well
  - GET '/posts?title=foo&author=bar'
    - title = params['title']
    - author = params['author']

- static files are served from the public directory

- view templates : erb(:index) -> renders index.erb, returns string
