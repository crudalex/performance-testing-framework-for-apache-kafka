enc:
	@openssl aes-256-cbc -a -salt -pbkdf2 -in .env -out env.enc

dec: 
	@cat env.enc |  base64 -d  | openssl enc -d -aes-256-cbc -pbkdf2 -out .env
