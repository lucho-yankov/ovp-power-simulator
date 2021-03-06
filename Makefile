#
# Host gcc
# Makefile for compiling ICM platform to platfrom.so / platform.dll & platform.exe
#

IMPERAS_HOME := $(shell getpath.exe "$(IMPERAS_HOME)")

include $(IMPERAS_HOME)/bin/Makefile.include

ifndef IMPERAS_HOME
  IMPERAS_ERROR := $(error "IMPERAS_HOME not defined")
endif

include $(IMPERAS_HOME)/ImperasLib/buildutils/Makefile.common

SRC?=platform.c
SUFFIX=$(suffix $(SRC))

ifeq ($(SUFFIX),)
  IMPERAS_ERROR:=$(error Please specify full platform source file name. File suffix could not be determined!)
endif

ifeq ($(SUFFIX),.c)
  CC=$(HOST_GCC)
  #
  # Additional dependency
  #
  CDEP += $(patsubst %.c, $(OBJDIR)/%.d, $(SRC))
else
  CC=$(HOST_GXX)
endif

EXECUTABLE?=$(SRC:$(SUFFIX)=.$(IMPERAS_ARCH).exe)
SHAREDOBJ?=$(SRC:$(SUFFIX)=.$(IMPERAS_ARCH).$(IMPERAS_SHRSUF))
SHAREDOBJCLN2?=$(SRC:$(SUFFIX)=.$(IMPERAS_SHRSUF))
PLATOBJ?=$(OBJDIR)/$(SRC:$(SUFFIX)=.o)

#
# platform.tcl ->
# platform.igen.stubs
#
IGEN?= igen.exe
IGENFLAGS?= --quiet --nobanner --excludem GPT_NH --excludem GPT_UFNR
#
# do not load all XML files into igen by default
#
USERINIT?=0
ifeq ($(USERINIT),0)
    IGENFLAGS+= --nouserinit
endif
PLATFORM-TCL ?= $(wildcard platform.tcl)
PLATFORM-SRC ?= $(patsubst %.tcl, %.c.igen.stubs,       $(PLATFORM-TCL))
PLATFORM-INC  = $(patsubst %.tcl, %.clp.igen.h,         $(PLATFORM-TCL)) \
                $(patsubst %.tcl, %.constructor.igen.h, $(PLATFORM-TCL)) \
                $(patsubst %.tcl, %.handles.igen.h,     $(PLATFORM-TCL)) \
                $(patsubst %.tcl, %.options.igen.h,     $(PLATFORM-TCL))

#
# Does the SRC exist ?
#
COPYSTUBS = 0
ifeq ("$(wildcard $(SRC))","")
    COPYSTUBS = 1
endif

all: $(WORKDIR)/$(EXECUTABLE) $(WORKDIR)/$(SHAREDOBJ)

# include all the dependancy requirements
ifneq ($(MAKECMDGOALS),clean)
$(foreach dep,$(CDEP),$(eval -include $(dep)))
endif

$(SRC): $(PLATFORM-SRC)
ifeq ($(COPYSTUBS),1)
	@    echo "# Copying STUBS $(^) to $(@)"
	$(V) cp $(^) $(@)
endif

%.c.igen.stubs %.clp.igen.h %.constructor.igen.h %.handles.igen.h %.options.igen.h: %.tcl
	@    echo "# Igen Create ICM PLATFORM $*"
	$(V) $(IGEN) $(IGENFLAGS)				\
		--batch     $(<)					\
		--writec    $(*)					\
		--writexml  $(@D)/platform.igen.xml	\
		$(WRITEHEADER)			            \
		--overwrite

$(WORKDIR)/$(EXECUTABLE): $(PLATOBJ) $(OBJDIR)/hexLoader.o $(OBJDIR)/currentUsage.o $(OBJDIR)/instructions_analyser.o $(OBJDIR)/cycles_table.o $(OBJDIR)/ppi.o $(OBJDIR)/commonPeripherals.o # make it general
	$(V) mkdir -p $(@D)
	@    echo "# Host Linking Platform $@"
	$(V) sleep 1
	$(V) strace $(CC) -o $@ $^ $(SIM_LDFLAGS) $(LDFLAGS) $(IMPERAS_ICMSTUBS)
	$(V) # if we are not compiling locally, copy out the .xml files to the destination
ifeq ($(COPYXML),1)
	@    echo "# Copying XML $(XML) to $(@D)"
	$(V) cp $(XML) $(@D)
endif

$(WORKDIR)/$(SHAREDOBJ): $(PLATOBJ) $(OBJDIR)/hexLoader.o $(OBJDIR)/currentUsage.o $(OBJDIR)/instructions_analyser.o $(OBJDIR)/cycles_table.o $(OBJDIR)/ppi.o $(OBJDIR)/commonPeripherals.o # make it general
	$(V) mkdir -p $(@D)
	@    echo "# Host Linking Platform object $@"
	$(V) strace $(CC) -shared -o $@ $^ $(SIM_LDFLAGS) $(LDFLAGS) $(IMPERAS_ICMSTUBS)

SRC_SUFFIX = c cpp c++ cxx
define SRC_SUFFIX_Template
$(OBJDIR)/%.d: src/%.$(1)
	@ echo "# Host Depending $$@"
	@ echo "$$(CC) -MM $$< $$(SIM_CFLAGS) $$(CFLAGS) $$(LDFLAGS) -MT $$(OBJDIR)/$$*.o -MF $$@"
	$$(V) mkdir -p $$(@D)
	$$(V) strace $$(CC) -MM $$< $$(SIM_CFLAGS) $$(CFLAGS) $$(LDFLAGS) -MT $$(OBJDIR)/$$*.o -MF $$@
	@ # If you use Posix or proper mingw probably you don't need the following line
	$$(V) sed -i -r 's/(\w):\//\/cygdrive\/\1\//' $$@

$(OBJDIR)/%.o: src/%.$(1)
	$$(V) mkdir -p $$(@D)
	@     echo "# Host Compiling Platform $$@"
	$$(V) echo "$$(V) $$(CC) -c -o $$@ $$< $$(SIM_CFLAGS) $$(CFLAGS)"
	$$(V) strace $$(CC) -c -o $$@ $$< $$(SIM_CFLAGS) $$(CFLAGS)
endef
$(foreach X,$(SRC_SUFFIX),$(eval $(call SRC_SUFFIX_Template,$(X))))

clean::
	$(V) - rm -f $(WORKDIR)/$(EXECUTABLE) $(WORKDIR)/$(SHAREDOBJ) $(WORKDIR)/$(SHAREDOBJCLN2)
	$(V) - rm -rf $(OBJDIR)
	$(V) - rm -f $(PLATFORM-SRC) $(PLATFORM-INC)
