CFLAGS+=-Werror
CFLAGS+=-Wall
CFLAGS+=-Wformat
CFLAGS+=-Wpointer-arith
CFLAGS+=-Wcast-align
CFLAGS+=-Wcast-qual
CFLAGS+=-Wreturn-type
CFLAGS+=-Wextra
CFLAGS+=-Wstrict-prototypes
#CFLAGS+=-Wmissing-declarations
#CFLAGS+=-Wmissing-prototypes

#CFLAGS+=-g
#CFLAGS+=-ggdb
#LDFLAGS+=-static-libgcc
#LDFLAGS+=-static-libstdc++

$(libpbutil_a_OBJECTS): $(CONFIG_HEADER)

noinst_LIBRARIES=libpbutil.a
libpbutil_a_SOURCES=
libpbutil_a_SOURCES+=pbutil.h
libpbutil_a_SOURCES+=pbutil_priv.h
#libpbutil_a_SOURCES+=dirent.h
libpbutil_a_SOURCES+=pbu_basename.c
libpbutil_a_SOURCES+=pbu_copy_file.c
#libpbutil_a_SOURCES+=pbu_dirent.c
libpbutil_a_SOURCES+=pbu_ext.c
libpbutil_a_SOURCES+=pbu_extend_path.c
libpbutil_a_SOURCES+=pbu_list.c
libpbutil_a_SOURCES+=pbu_malloc.c
libpbutil_a_SOURCES+=pbu_mkdir.c
libpbutil_a_SOURCES+=pbu_msvcrt.c
libpbutil_a_SOURCES+=pbu_s2w.c
libpbutil_a_SOURCES+=pbu_w2s.c
libpbutil_a_SOURCES+=pbu_same_file.c
libpbutil_a_SOURCES+=pbu_strtok.c
libpbutil_a_SOURCES+=pbu_trace.c
libpbutil_a_SOURCES+=pbu_wcstok.c
