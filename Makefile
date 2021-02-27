# This is a given Makefile for all jotaOS user space programs
# Read the documentation to understand its options

ifndef PROJNAME
$(error You have to set a project name (PROJNAME))
endif
ifndef RESULT
$(error You have to set a result file (RESULT))
endif

SRCPATH := src
OBJPATH := obj

CXX := amd64-elf-g++
INCLUDES := -Isrc

CXXFLAGS_BASE := -std=c++11 -ffreestanding -O3
CXXFLAGS_WARN := -Wall -Wextra -Werror
CXXFLAGS_EXCLUDE := -fno-exceptions -fno-rtti -fno-use-cxa-atexit -fno-stack-protector -fpic -fpie -fomit-frame-pointer -mno-red-zone -mno-80387 -mno-mmx -mno-3dnow -mno-sse
CXXFLAGS := $(INCLUDES) $(CXXFLAGS_BASE) $(CXXFLAGS_WARN) $(CXXFLAGS_EXCLUDE)

ifdef asm
ASM := nasm
ASMFLAGS := -f elf64
endif


LINKER := $(CXX)
ifdef LINKER_FILE
LINKER_FLAGS := -T $(LINKER_FILE)
endif
LINKER_FLAGS := $(LINKER_FLAGS) -nostdlib -pie -z max-page-size=0x1000


CXX_OBJS := $(shell cd src && find . -type f -iname '*.cpp' | sed 's/\.\///g' | sed 's/\.cpp/\.o/g' | xargs -I {} echo "$(OBJPATH)/"{})
ifndef asm
ALL_OBJS := $(shell echo "$(CXX_OBJS)" | xargs -n1 | sort | xargs)
else
ASM_OBJS := $(shell cd src && find . -type f -iname '*.asm' | sed 's/\.\///g' | sed 's/\.asm/\.o/g' | xargs -I {} echo "$(OBJPATH)/"{})
ALL_OBJS := $(shell echo "$(CXX_OBJS) $(ASM_OBJS)" | xargs -n1 | sort | xargs)
endif


.PHONY: all clean
all: $(RESULT)

$(RESULT): $(ALL_OBJS)
	@echo "[$(PROJNAME)] Linking..."
	@$(LINKER) `find $(OBJPATH) -type f -iname '*.o'` -o $@ $(LINKER_FLAGS)
	@echo "[$(PROJNAME)] Stripping..."
	@strip $(RESULT)

-include $(CXX_OBJS:.o=.o.d)

$(ALL_OBJS): | $(OBJPATH)

$(CXX_OBJS): $(OBJPATH)/%.o: $(SRCPATH)/%.cpp
	@echo "[$(PROJNAME)] ===> $<"
	@$(CXX) -c -o $@ $< $(CXXFLAGS)
	@$(CXX) -MM $< -o $@.d.tmp $(CXXFLAGS)
	@sed -e 's|.*:|$@:|' < $@.d.tmp > $@.d
	@rm -f $@.d.tmp

ifdef asm
$(ASM_OBJS): $(OBJPATH)/%.o: $(SRCPATH)/%.asm
	@echo "[$(PROJNAME)] ===> $<"
	@$(ASM) $< -o $@ $(ASMFLAGS)
endif

$(OBJPATH):
	@echo "[$(PROJNAME)] Creating $(OBJPATH)/ hierarchy..."
	@cd src && find . -type d -exec mkdir -p ../$(OBJPATH)/{} \;

clean:
	rm -rf $(RESULT) $(OBJPATH)/
