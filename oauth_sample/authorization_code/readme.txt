# -----------------------------------------------
# This sample is made for google Oauth 2.0
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

vi ./def/${provider}_oauth_form.html.def
#------------------------------------------------
# target params
  var CLIENT_ID = '';
  var REDIRECT_URI = '';
  var OAUTH_END_POINT = '';
  var SCOPE = '';
  var STATE = '';
#-------------------------------------------------

# DEPLOY
authkey=$(grep authkey= /var/www/cgi-bin/auth.$app | sed "s/authkey=\"//g" | sed "s/\"//g")
echo $authkey
cat ./cgi-bin/${provider}_auth | sed "s/%%authkey/${authkey}/g" | sed "s/%%app/${app}/g" > .auth.$app
sudo cp .auth.$app /var/www/cgi-bin/auth.$app
. /usr/local/small-shell/web/base 
cat ./def/${provider}_oauth_form.html.def | sed "s#%%static_url/#$static_url#g" | sed "s/%%app/${app}/g" > .${app}_auth_form.html.def
sudo cp .${app}_auth_form.html.def /var/www/def/${app}_auth_form.html.def
sudo chmod 755 /var/www/cgi-bin/auth.$app

Then you can try to connect the APP.
https://XXXX/cgi-bin/auth.$app
