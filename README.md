# README

Set up Ruby, Postgres and Github on local env and install necessary gems. follow instructions here - https://gocardless.atlassian.net/wiki/spaces/TE/pages/1142522761/Environment+Setup

Pull code, change to develop / branch off develop

Modify database creds in config/database/yml

cd into root folder 
   Run 'bundle install' to install dependencies
   
* Database initialization
   Run 'bin/rails server' to start app
   
   Run 'bin/rails db:migrate' to run migrations    

* How to use app
  
  Acess endpoints on localhost:3000

* Deployment instructions
cd into root folder
  Run 'heroku git:remote -a fathomless-temple-12276' to connect with existing app
  
  Run 'heroku config:set RAILS_ENV=test' to set environment to test on heroku
  
  Run 'git push heroku your-branch:master' to deploy to rails 
  
  Run 'heroku run rake db:migrate' to run migrations on heroku
  
