# This is a given Makefile for all Strife projects

MAKEFLAGS += -s

ERR_PROJNAME := You have to set a project name (PROJNAME)
ERR_RESULT := You have to set a result file (RESULT)
ERR_HEADERS := Please set the STRIFE_STDLIB_HEADERS environment variable to the pubheaders/ directory of stdlib
ERR_LIBS := Please set the STRIFE_LIBS environment variable to a directory containing the requested libraries

ifndef PROJNAME
	$(error $(ERR_PROJNAME))
endif
ifndef RESULT
	$(error $(ERR_RESULT))
endif

SHELL := /bin/bash
SRCPATH := src
OBJPATH := obj

# --- CXX ---
CXX := amd64-elf-g++
INCLUDES := -Isrc
ifndef nostdlibh
	ifndef STRIFE_STDLIB_HEADERS
		$(error $(ERR_HEADERS))
	endif
	INCLUDES += -I "$(STRIFE_STDLIB_HEADERS)" -I "$(STRIFE_STDLIB_HEADERS)/STL"
endif

CXXFLAGS_BASE := -std=c++11 -ffreestanding -O2 -fpic -fpie -fPIC
CXXFLAGS_WARN := -Wall -Wextra -Werror
CXXFLAGS_EXCLUDE := -fno-exceptions -fno-rtti -fno-use-cxa-atexit -fno-stack-protector -fomit-frame-pointer -mno-red-zone -mno-80387 -mno-mmx -mno-3dnow -mno-sse
ifdef shared
	CXXFLAGS_BASE += -export-dynamic -shared
endif
ifdef DEBUG
	CXXFLAGS_BASE += -g
endif
CXXFLAGS := $(INCLUDES) $(CXXFLAGS_BASE) $(CXXFLAGS_WARN) $(CXXFLAGS_EXCLUDE)

# --- ASM ---
ifdef asm
	ASM := nasm
	ASMFLAGS := -f elf64
	ifdef DEBUG
		ASMFLAGS += -g
	endif
endif


# --- LINKER ---
LINKER := amd64-elf-ld
LINKER_FLAGS += -pie
ifdef lib
	LINKER_FLAGS += -shared
endif

LINKER_FLAGS += -L$(STRIFE_LIBS)

ifndef nostdlib
	ifndef STRIFE_LIBS
		$(error $(ERR_LIBS))
	endif
	LINKER_FLAGS_END += -lstd
endif

ifdef static
	LINKER_FLAGS += -static
endif

ifdef LINKER_FILE
	LINKER_FLAGS += -T $(LINKER_FILE)
endif
LINKER_FLAGS += -nostdlib -z max-page-size=0x1000
LINKER_FLAGS += -z relro -z now


# --- OBJS ---
OBJPATHS := $(shell cd src && find . -type d | xargs -I {} echo "$(OBJPATH)/"{})

CXX_OBJS := $(shell cd src && find . -type f -iname '*.cpp' | sed 's/\.\///g' | sed 's/\.cpp/\.o/g' | xargs -I {} echo "$(OBJPATH)/"{})
ifndef asm
	ALL_OBJS := $(shell echo "$(CXX_OBJS)" | xargs -n1 | sort | xargs)
else
	ASM_OBJS := $(shell cd src && find . -type f -iname '*.asm' | sed 's/\.\///g' | sed 's/\.asm/\.o/g' | xargs -I {} echo "$(OBJPATH)/"{})
	ALL_OBJS := $(shell echo "$(CXX_OBJS) $(ASM_OBJS)" | xargs -n1 | sort | xargs)
endif


.PHONY: all clean
all: $(RESULT)
	@

$(RESULT): $(ALL_OBJS)
	@echo "[$(PROJNAME)] Linking..."
	@$(LINKER) $(LINKER_FLAGS) $(ALL_OBJS) $(LINKER_FLAGS_END) -o $@
	@if [[ ! -v DEBUG ]]; then \
		echo "[$(PROJNAME)] Stripping..."; \
		strip $(RESULT); \
	fi
	@if [[ ! -z "$(STATICRESULT)" ]]; then \
		echo "[$(PROJNAME)] Creating static library..."; \
		ar rcs $(STATICRESULT) $(ALL_OBJS); \
	fi

-include $(CXX_OBJS:.o=.o.d)

$(ALL_OBJS): | $(OBJPATHS)

$(CXX_OBJS): $(OBJPATH)/%.o: $(SRCPATH)/%.cpp
	@echo "[$(PROJNAME)] ===> $<"
	@$(CXX) -c -o $@ $< $(CXXFLAGS)
	@$(CXX) -MM $< -o $@.d.tmp $(CXXFLAGS)
	@sed -e 's|.*:|$@:|' < $@.d.tmp > $@.d
	@rm -f $@.d.tmp

ifdef asm
$(ASM_OBJS): $(OBJPATH)/%.o: $(SRCPATH)/%.asm
	@echo "[$(PROJNAME)] ===> $<"
	@$(ASM) -i $(shell dirname $<) $< -o $@ $(ASMFLAGS)
endif

$(OBJPATHS): $(OBJPATH)/%: $(SRCPATH)/%
	@mkdir -p $(OBJPATH)/$*

clean:
	rm -rf $(RESULT) $(STATICRESULT) $(OBJPATH)/
