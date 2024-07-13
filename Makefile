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
	$(shell echo 'IyA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PQojICAgRGF0YWJhc2UgZW52cwojID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09CgojIERvY2tlciBjb250YWluZXIgaW5mbwpEQl9ET0NLRVJfSE9TVD0KREJfRE9DS0VSX1BPUlQ9CkRCX1BPU1RHUkVTX1ZFUlNJT049bGF0ZXN0CkRCX0NPTlRBSU5FUl9OQU1FPXMzcC1wb3N0Z3Jlc3FsCkRCX0RPQ0tFUl9TRVJWSUNFX05BTUU9ZGItcG9zdGdyZXMKCiMgQ3JlZGVudGlhbHMKREJfVVNFUj0KREJfUEFTU1dPUkQ9CkRCX0RBVEFCQVNFPQoKIyBEaXJzCkRCX0RBVEFfRElSPWRiCkxPR19ESVI9bG9ncwoKIyBJbml0aWFsIFNjcmlwdHMKREJfUk9MRV9TQ1JJUFQ9dXNlcnMucm9sZXMuc3FsCkRCX0lOSVRfU0NSSVBUPXN0YXJ0dXAuc3FsCkRCX0RBVEFfU0NSSVBUPWRhdGEuc3FsCgo=' | base64 -Dd > .env.sample)

clean:
	$(shell docker-compose down)
	$(shell rm -rf $(DB_DATA_DIR))
	$(shell rm -rf $(LOG_DIR))

endif

