# Add that initial user only local host can add
kcAdmin=`cat kc-admin`
./keycloak/bin/add-user-keycloak.sh --server localhost:<port> -r master -u code-kitchen-admin -p "$kcAdmin"

# Log kcadm into a server
kcAdmin=`cat kc-admin`
./keycloak/bin/kcadm.sh config credentials --server https://sso.foodyfood.cloud/auth --realm master --user code-kitchen-admin --password "$kcAdmin"

# Create a client under a realm, need the realm created first
./keycloak/bin/kcadm.sh create clients -r code-kitchen -s clientId=code-kitchen -s enabled=true -s clientAuthenticatorType=client-secret -s secret=<big-secret>

# Valid redirect url
https://code-kitchen.example.com/*

# If you forget the secret, you can find it in the KC UI
# Client - > Credentials 