# Client configuration
For each new client that you wish to create, you must create a client
file containing unique information for each MQTT client certificate as
well as the client's username and password.

Therefore, you must create a file named "*.client", where * is the
unique name of the client.

The client file contains one line, with several fields separated by
semicolons.  The first column contains the subject line of the
client's certificate.  The second and third fields contain the
username and password used in authentication with the MQTT broker. 
Fanally, the fourth field contains the client's certificate validity period. 
This field is optional and the default value is 365 days.

Example:
```config
/C=IT/ST=Italy/L=Italy/O=Example/OU=Client/CN=email@example.com;example;Secure[;100]
```

