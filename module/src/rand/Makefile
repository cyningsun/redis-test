

REDIS_VERSION=6.2.6
REDIS_DOWNLOAD_URL="http://download.redis.io/releases/redis-6.2.6.tar.gz"
REDIS_DOWNLOAD_SHA="5b2b8b7a50111ef395bf1c1d5be11e6e167ac018125055daa8b5c2317ae131ab"

build:
	# download redis
	curl -o redis.tar.gz -L "$(REDIS_DOWNLOAD_URL)"
	echo "$(REDIS_DOWNLOAD_SHA) *redis.tar.gz" | sha256sum -c -
	# create temp dir
	mkdir -p /tmp/redis
	# extract redis
	tar -xzf redis.tar.gz -C /tmp/redis --strip-components=1
	# build module 
	gcc -shared -fpic -o rand.so rand.c -I/tmp/redis/src/
