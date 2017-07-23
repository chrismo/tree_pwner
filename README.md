## Usage

bundle exec pry

## Get A New Token

Ok. What's stored in the client_secret.[email@addr].json files is the OAuth 2.0 credentials that you obtain 
from the https://console.developers.google.com/apis/credentials url. This shouldn't expire.

THEN ... if you have an expired token, you'll need to remove the entry from tokens.yaml, then re-run and you
should get prompted to visit a URL to get a new token value. Paste this into the console where shown, then
tokens.yaml will be saved for you automatically with this new value in it.
