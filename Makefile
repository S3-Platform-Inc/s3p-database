# Import env
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# get OS name
OS := $(shell uname)

current-os:
	@echo "$(OS) os. Use 'make dev' to init dev db"

ifeq ($(OS), Darwin)
##################################
#       Run MacOS commands       #
##################################

# dir that contains database storage
$(DB_DATA_DIR):
	@mkdir $@

# dir that contains the logs
$(LOG_DIR):
	@mkdir $@

docker: | setup-env-files
	$(shell docker-compose up -d --build)

setup-env-files: $(DB_DATA_DIR) $(LOG_DIR)

dev: docker | setup-env-files

env:
	$(shell echo 'IyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICAgRGF0YWJhc2UgZW52cwojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIERvY2tlciBjb250YWluZXIgaW5mbwpEQl9ET0NLRVJfUE9SVD0xMDkwMQpEQl9QT1NUR1JFU19WRVJTSU9OPWxhdGVzdApEQl9DT05UQUlORVJfTkFNRT1zM3AtcG9zdGdyZXNxbApEQl9ET0NLRVJfU0VSVklDRV9OQU1FPWRiLXBvc3RncmVzCgojIENyZWRlbnRpYWxzCkRCX1VTRVI9c3BwYWRtaW4KREJfUEFTU1dPUkQ9ZXhhbXBsZV9wYXNzd29yZF9zM3BhZG1pbgpEQl9EQVRBQkFTRT1zcHBJbnRlZ3JhdGVEQgoKIyBEaXJzCkRCX0RBVEFfRElSPWRiCkxPR19ESVI9bG9ncwoKIyBJbml0aWFsIFNjcmlwdHMKREJfUk9MRV9TQ1JJUFQ9cm9sZXMuc3FsCkRCX0lOSVRfU0NSSVBUPXN0YXJ0dXAuc3FsCkRCX0RBVEFfU0NSSVBUPWRhdGEuc3FsCgo=' | base64 -Dd > .env.sample)

clean:
	$(shell docker-compose down)
	$(shell rm -rf $(DB_DATA_DIR))
	$(shell rm -rf $(LOG_DIR))

endif

