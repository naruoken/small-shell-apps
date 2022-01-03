# -----------------------------------------------
# This sample is made for okta or google Oauth 2.0
# -----------------------------------------------

# input small-shell app name
app="XXXX"
echo $app

cd $HOME
git clone https://github.com/naruoken/small-shell-apps

# select provider
provider="gcp"
#provider="okta"

cd small-shell-apps/oauth_sample/authorization_code

# UPDATE PARAMA
vi ./cgi-bin/${provider}_auth
#------------------------------------------------
# target params
exchange_token_uri=""
user_info_req_uri=""
redirect_uri=""
client_id=""
client_secret=""
target_claim=""
#-------------------------------------------------
# sample input
#------------------------------------------------
#exchange_token_uri="https://oauth2.googleapis.com/token"
#user_info_req_uri="https://www.googleapis.com/oauth2/v1/userinfo?"
#redirect_uri="http://XXX/cgi-bin/auth.oauth_test"
#client_id="XXX.apps.googleusercontent.com"
#client_secret="XXXX"
#target_claim="email"

vi ./descriptor/${provider}_oauth_form.html.def
#------------------------------------------------
# target params
  var CLIENT_ID = '';
  var REDIRECT_URI = '';
  var OAUTH_END_POINT = '';
  var SCOPE = '';
  var STATE = '';
#-------------------------------------------------
# sample input
#------------------------------------------------
#  var CLIENT_ID = 'XXXX.apps.googleusercontent.com';
#  var REDIRECT_URI = 'http://XXXX/cgi-bin/auth.oauth_test';
#  var OAUTH_END_POINT = 'https://accounts.google.com/o/oauth2/v2/auth';
#  var SCOPE = 'https://www.googleapis.com/auth/userinfo.email';
#  var STATE = 'statee';
#------------------------------------------------ 


# DEPLOY
authkey=`grep authkey= /usr/lib/cgi-bin/auth.$app | sed "s/authkey=\"//g" | sed "s/\"//g"`
echo $authkey
cat ./cgi-bin/${provider}_auth | sed "s/%%authkey/$authkey/g" > /usr/lib/cgi-bin/auth.$app
cat ./descriptor/${provider}_oauth_form.html.def > /var/www/descriptor/${app}_auth_form.html.def

Then you can try to connect the APP.
https://XXXX/cgi-bin/auth.$app
