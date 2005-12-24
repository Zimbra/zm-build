DROP DATABASE IF EXISTS license;
CREATE DATABASE license;

USE license;

GRANT ALL ON license.* to 'license' IDENTIFIED BY 'licensing';
GRANT ALL ON license.* to 'license'@'localhost' IDENTIFIED BY 'licensing';

# Customers

CREATE TABLE customer (
	id	 		INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	name 		VARCHAR(255) NOT NULL,

	UNIQUE INDEX i_name (name(100))
);

# Foreign keys (SF id, etc)

CREATE TABLE fk (
	customer_id		VARCHAR(255) NOT NULL,
	fk				VARCHAR(255) NOT NULL,
	comment			VARCHAR(255),

	PRIMARY KEY (customer_id(100), fk(100))
);

# Keys

CREATE TABLE sign_keys (
	id			INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	pubkey		TEXT NOT NULL,
	privkey		TEXT NOT NULL,
	gendate		DATETIME NOT NULL,
	expiredate	DATETIME NOT NULL,
	is_expired	BOOL NOT NULL DEFAULT 0
);

# Licenses

CREATE TABLE customer_license (
	id					INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
	expiration			DATETIME NOT NULL,
	customer_id			VARCHAR(255) NOT NULL,
	license_text		TEXT,
	license_version		INT UNSIGNED NOT NULL,
	is_deleted			BOOL NOT NULL DEFAULT 0
);

# License Details

CREATE TABLE license_details (
	license_id			INT NOT NULL,
	name				VARCHAR(64) NOT NULL,
	value				VARCHAR(255) NOT NULL
);

# License info
#
# Customer Name
# Customer ID
# License ID
# 
# Required fields
# 	Key ID
# 	Generation date
# 	Expiration date
# 
