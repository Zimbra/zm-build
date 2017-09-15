IMAGES =
IMAGES += devcore-ubuntu-16.04
IMAGES += devcore-ubuntu-14.04
IMAGES += devcore-ubuntu-12.04
IMAGES += devcore-centos-7
IMAGES += devcore-centos-6
IMAGES += core-ubuntu

PUSH_IMGS = $(patsubst %,.push-%,$(IMAGES))
BUILD_IMGS = $(patsubst %,.build-%,$(IMAGES))

all: $(PUSH_IMGS)

$(BUILD_IMGS): .build-% : Dockerfile-%
	@docker build -t zimbra/zm-base-os:$* -f $< .
	@touch $@

$(PUSH_IMGS): .push-% : .build-%
	@docker push zimbra/zm-base-os:$*
	@touch $@

clean:
	@rm -f $(PUSH_IMGS) $(BUILD_IMGS)
