# -----------------------------------------------
# This sample is made for okta or google Oauth 2.0
# -----------------------------------------------

# please input small-shell app name
app="XXX"
echo $app

cd $HOME

# select provider
provider="gcp"
#provider="okta"

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
#------------------------------------------------

vi ./descriptor/${provider}_auth_form.html.def
#------------------------------------------------
# target params
  var CLIENT_ID = '';
  var REDIRECT_URI = '';
  var OAUTH_END_POINT = '';
  var SCOPE = '';
  var STATE = '';
#-------------------------------------------------

# DEPLOY TO APP
authkey=`grep authkey /usr/lib/cgi-bin/auth.$app`
cat ./cgi-bin/${provider}_auth | sed "s/%%authkey/$authkey/g" > /usr/lib/cgi-bin/auth.$app
cat ./descriptor/${provier}_auth_form.html.def > /var/www/descriptor/${app}_auth_form.html.def

cat /usr/lib/cgi-bin/auth.$app
cat /var/www/descriptor/auth.$app


that's all thanks !
