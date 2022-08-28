# -----------------------------------------------
# This sample is made for okta or google Oauth 2.0
# -----------------------------------------------

# input small-shell app name
app="XXXX"
echo $app
SED=sed
AWK=awk

# if you are mac user, please set gnu command
#SED=gsed
#AWK=gawk

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

vi ./descriptor/${provider}_oauth_form.html.def
#------------------------------------------------
# target params
  var CLIENT_ID = '';
  var REDIRECT_URI = '';
  var OAUTH_END_POINT = '';
  var SCOPE = '';
  var STATE = '';
#-------------------------------------------------

# DEPLOY
authkey=`grep authkey= /usr/lib/cgi-bin/auth.$app | $SED "s/authkey=\"//g" | $SED "s/\"//g"`
echo $authkey
cat ./cgi-bin/${provider}_auth | $SED "s/%%authkey/$authkey/g" > /usr/lib/cgi-bin/auth.$app
cat ./descriptor/${provider}_oauth_form.html.def > /var/www/descriptor/${app}_auth_form.html.def

Then you can try to connect the APP.
https://XXXX/cgi-bin/auth.$app
