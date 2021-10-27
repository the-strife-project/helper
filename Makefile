# This is a given Makefile for all jotaOS user space programs
# Read the documentation to understand its options

ERR_PROJNAME := You have to set a project name (PROJNAME)
ERR_RESULT := You have to set a result file (RESULT)
ERR_HEADERS := Please set the JOTAOS_STDLIB_HEADERS environment variable to the pubheaders/ directory of stdlib
ERR_LIBS := Please set the JOTAOS_LIBS environment variable to a directory containing the requested libraries

ifndef PROJNAME
$(error $(ERR_PROJNAME))
endif
ifndef RESULT
$(error $(ERR_RESULT))
endif

SRCPATH := src
OBJPATH := obj

# --- CXX ---
CXX := amd64-elf-g++
INCLUDES := -Isrc
ifndef nostdlibh
ifndef JOTAOS_STDLIB_HEADERS
$(error $(ERR_HEADERS))
endif
INCLUDES += -I "$(JOTAOS_STDLIB_HEADERS)"
endif

CXXFLAGS_BASE := -std=c++11 -ffreestanding -O3 -fpic -fpie
CXXFLAGS_WARN := -Wall -Wextra -Werror
CXXFLAGS_EXCLUDE := -fno-exceptions -fno-rtti -fno-use-cxa-atexit -fno-stack-protector -fomit-frame-pointer -mno-red-zone -mno-80387 -mno-mmx -mno-3dnow -mno-sse
ifdef shared
CXXFLAGS_BASE += -export-dynamic -shared
endif
ifdef static
CXXFLAGS_BASE += -static
endif
CXXFLAGS := $(INCLUDES) $(CXXFLAGS_BASE) $(CXXFLAGS_WARN) $(CXXFLAGS_EXCLUDE)

ifdef asm
ASM := nasm
ASMFLAGS := -f elf64
endif


# --- LINKER ---
LINKER := amd64-elf-ld
LINKER_FLAGS := -pie
ifdef lib
LINKER_FLAGS += -shared
endif
ifdef static
LINKER_FLAGS += -static
endif

ifndef nostdlib
ifndef JOTAOS_LIBS
$(error $(ERR_LIBS))
endif
LINKER_FLAGS += -L$(JOTAOS_LIBS) -lstd
endif

ifdef LINKER_FILE
LINKER_FLAGS += -T $(LINKER_FILE)
endif
LINKER_FLAGS += -nostdlib -z max-page-size=0x1000
LINKER_FLAGS += -z relro -z now


# --- OBJS ---
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
	@$(LINKER) $(LINKER_FLAGS) $(ALL_OBJS) -o $@
	@if [[ -v RESULTSTATIC ]]; then ar rcs $(RESULTSTATIC) $(ALL_OBJS); fi
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
	rm -rf $(RESULT) $(RESULTSTATIC) $(OBJPATH)/
