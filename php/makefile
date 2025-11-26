run-server:
	docker run --rm -p 2000:2000 -v $(PWD):/app --name swoole-app swoole-server

run-client:
	docker run --rm --network host -v $(PWD):/app -w /app swoole-server php client.php

build:
	docker build -t swoole-server .
