/*
 * bs1770gain_tree.c
 * Copyright (C) 2014, 2015 Peter Belkner <pbelkner@users.sf.net>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2.0 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA  02110-1301  USA
 */
#include <bs1770gain_priv.h>
#include <sys/types.h>
#include <sys/stat.h>

#if defined (_WIN32) // {
#define CLOSEDIR(d)   _wclosedir(d)
#define READDIR(d)    _wreaddir(d)
#else // } {
#define CLOSEDIR(d)   closedir(d)
#define READDIR(d)    readdir(d)
#endif // }

///////////////////////////////////////////////////////////////////////////////
bs1770gain_tree_t *bs1770gain_tree_init(bs1770gain_tree_t *tree,
    const bs1770gain_tree_vmt_t *vmt, bs1770gain_tree_t *root,
    const bs1770gain_tree_t *parent)
{
  tree->vmt=vmt;
  tree->root=root;
  tree->parent=parent;
  tree->path=NULL;
  tree->basename=NULL;
  tree->state=BS1770GAIN_TREE_STATE_INV;
  tree->ai=-1;
  tree->vi=-1;

  return tree;
}

///////////////////////////////////////////////////////////////////////////////
static void bs1770gain_ffmpeg_dump(const char *path)
{
  AVFormatContext *ifc;

  ifc=NULL;

  if (avformat_open_input(&ifc,path,NULL,NULL)<0)
    goto ifc;

  if (avformat_find_stream_info(ifc, NULL)<0)
    goto find;

  av_dump_format(ifc,0,path,0);
find:
  avformat_close_input(&ifc);
ifc:
  return;
}

int bs1770gain_tree_analyze(tree_t *tree, const char *odirname,
    options_t *options)
{
  int code=-1;
  const bs1770gain_tree_t *parent=tree->parent;
  const char *ibasename=NULL==parent?NULL:parent->basename;
  bs1770gain_print_t *p=&options->p;
  FILE *f=p->vmt->session.file(p);
  bs1770gain_album_t *album;
  bs1770gain_track_t *track;
  const char *label;
  analyze_config_t ac;

  TRACE_PUSH();
  album=bs1770gain_album_new(NULL==parent?NULL:parent->path,odirname,options);

  if (NULL==album) {
    DMESSAGE("allocation album");
    goto album;
  }

  while (0<tree->vmt->next(tree,options)) {
    switch (tree->state) {
    case BS1770GAIN_TREE_STATE_REG:
      if (bs1770gain_tree_track(tree,album,options)<0) {
        DMESSAGE("initializing track");
        goto track;
      }

      break;
    case BS1770GAIN_TREE_STATE_DIR:
      if (bs1770gain_tree_album(tree,odirname,options)<0) {
        DMESSAGE("initializing album");
        goto track;
      }

      break;
    default:
      break;
    }
  }

  bs1770gain_album_renumber(album);

  if (NULL==album->head)
    ;
  else if (0==options->dump) {
    p->vmt->album.head(p,album,ibasename);

    for (track=album->head;NULL!=track;track=track->next) {
      p->vmt->track.head(p,track);

      memset(&ac,0,sizeof ac);
      ac.path=track->ipath;
      ac.aggregate=&track->aggregate;
      ac.stereo=options->stereo;
      ac.drc=options->drc;
      ac.momentary.ms=options->momentary.ms;
      ac.momentary.partition=options->momentary.partition;
      ac.shortterm.ms=options->shortterm.ms;
      ac.shortterm.partition=options->shortterm.partition;
      ac.f=f;
      ac.dump=0;

      if (ffsox_analyze(&ac,options->audio,ac.vi=options->video)<0) {
        fprintf(f,"Error gathering track statistics.\n");
        goto analyze;
      }

      p->vmt->track.body(p,&track->aggregate,options);
      ffsox_aggregate_merge(&album->aggregate,&track->aggregate);
      p->vmt->track.tail(p);
    }

    if (BS1770GAIN_IS_MODE_ALBUM_TAGS(options->mode)) {
      p->vmt->track.head(p,NULL);
      p->vmt->track.body(p,&album->aggregate,options);
      p->vmt->track.tail(p);
    }

    if (NULL!=odirname) {
      label=BS1770GAIN_IS_MODE_APPLY(options->mode)?"transcoding":"remuxing";

      // print a massage.
      if (f) {
        if (NULL==ibasename||0==*ibasename)
          fprintf(f,"%s ...\n",label);
        else
          fprintf(f,"%s \"%s\" ...\n",label,ibasename);
      }

      // mkdir.
      pbu_mkdir(album->opath);

      // copy the tracks.
      for (track=album->head;NULL!=track;track=track->next)
        bs1770gain_transcode(track,options);

      // copy "folder.jpg" if requested.
      if (0!=(EXTENSION_JPG&options->extensions)&&NULL!=album->ipath)
        bs1770gain_album_copy_file(album,"folder.jpg");
    }

    p->vmt->album.tail(p);
  }
  else {
    for (track=album->head;NULL!=track;track=track->next)
      bs1770gain_ffmpeg_dump(track->ipath);
  }

  code=0;
analyze:
track:
  bs1770gain_album_close(album);
album:
  TRACE_POP();

  return code;
}

int bs1770gain_tree_track(bs1770gain_tree_t *tree, bs1770gain_album_t *album,
    bs1770gain_options_t *options)
{
  int code =-1;

  TRACE_PUSH();

  if (NULL==bs1770gain_track_new(tree->path,album,options)) {
    DMESSAGE("allocation album");
    goto track;
  }

  code=0;
// cleanup:
track:
  TRACE_POP();

  return code;
}

int bs1770gain_tree_album(const bs1770gain_tree_t *root, const char *odirname,
    bs1770gain_options_t *options)
{
  int code;
  char *path;
  bs1770gain_tree_t tree;
  FILE *f;

  TRACE_PUSH();
  code =-1;
  f=options->p.vmt->session.file(&options->p);

  if (NULL!=odirname) {
    if (NULL==(path=pbu_extend_path(odirname,root->basename))) {
      DMESSAGE("extending output path");
      goto path;
    }
  }
  else
    path=NULL;

  if (NULL==bs1770gain_tree_dir_init(&tree,root->root,root,root->path)) {
    DMESSAGE("initilaizing directory");
    goto dir;
  }

  if (f)
    fprintf(f,"%s\n",root->path);

  bs1770gain_tree_analyze(&tree,path,options);
  code=0;
// cleanp:
  tree.vmt->cleanup(&tree);
dir:
  if (NULL!=path)
    FREE(path);
path:
  TRACE_POP();

  return code;
}

static int bs1770gain_invalid_ext(const char *path)
{
  static const char *exts[]={
    "txt",
    "csv",
    "jpg",
    "jpeg",
    "png",
    "gif",
    NULL
  };

  const char *ext,**ep;

  ext=pbu_ext(path);

  for (ep=exts;NULL!=*ep;++ep) {
    if (0==strcasecmp(*ep,ext))
      return 1;
  }

  return 0;
}

static int bs1770gain_tree_multimedia(bs1770gain_tree_t *tree,
    const bs1770gain_options_t *options)
{
  int code=0;
  AVFormatContext *ifc=NULL;

  if (avformat_open_input(&ifc,tree->path,NULL,NULL)<0)
    goto ifc;

  if (avformat_find_stream_info(ifc,NULL)<0)
    goto find;

  tree->ai=options->audio;
  tree->vi=options->video;

  if (ffsox_audiostream(ifc,&tree->ai,&tree->vi)<0) {
    DMESSAGE("finding streams");
    goto find;
  }

  code=1;
// cleanup:
find:
  avformat_close_input(&ifc);
ifc:
  return code;
}

int bs1770gain_tree_stat(bs1770gain_tree_t *tree, char *path,
    const bs1770gain_options_t *options)
{
#if defined (_WIN32) // {
  struct _stat buf;
  wchar_t *wpath;
#else // } {
  struct stat buf;
#endif // }
  char *p;

  if (NULL!=path) {
    p=path+strlen(path);

    // TODO unicode.
    while (path<p&&('/'==p[-1]||'\\'==p[-1]))
      *--p=0;
  }

  tree->path=path;
  tree->basename=pbu_basename(path);
#if defined (_WIN32) // {
  wpath=pbu_s2w(path);

  if (NULL==wpath)
    tree->state=BS1770GAIN_TREE_STATE_INV;
  else if (_wstat(wpath,&buf)<0)
    tree->state=BS1770GAIN_TREE_STATE_INV;
#else // } {
  if (NULL==path)
    tree->state=BS1770GAIN_TREE_STATE_INV;
  else if (stat(path,&buf)<0)
    tree->state=BS1770GAIN_TREE_STATE_INV;
#endif // }
  else if (S_ISREG(buf.st_mode)) {
    if (bs1770gain_invalid_ext(pbu_ext(tree->path)))
      tree->state=BS1770GAIN_TREE_STATE_INV;
    else if (bs1770gain_tree_multimedia(tree,options))
      tree->state=BS1770GAIN_TREE_STATE_REG;
    else
      tree->state=BS1770GAIN_TREE_STATE_INV;
  }
  else if (S_ISDIR(buf.st_mode))
    tree->state=BS1770GAIN_TREE_STATE_DIR;
  else
    tree->state=BS1770GAIN_TREE_STATE_INV;

#if defined (_WIN32) // {
  if (NULL!=wpath)
    FREE(wpath);
#endif // }

  if (BS1770GAIN_TREE_STATE_REG==tree->state)
    ++tree->root->cli.count;

  return tree->state;
}

///////////////////////////////////////////////////////////////////////////////
const bs1770gain_tree_vmt_t *bs1770gain_tree_cli_vmt(void)
{
  static bs1770gain_tree_vmt_t vmt;

  if (NULL==vmt.cleanup) {
    vmt.cleanup=bs1770gain_tree_cli_cleanup;
    vmt.next=bs1770gain_tree_cli_next;
  }

  return &vmt;
};

bs1770gain_tree_t *bs1770gain_tree_cli_init(bs1770gain_tree_t *tree,
    int argc, char **argv, int optind)
{
  bs1770gain_tree_init(tree,bs1770gain_tree_cli_vmt(),tree,NULL);
  tree->cli.argc=argc;
  tree->cli.argv=argv;
  tree->cli.optind=optind;
  tree->cli.count=0;

  return tree;
}

void bs1770gain_tree_cli_cleanup(bs1770gain_tree_t *tree)
{
  (void)tree;
}

int bs1770gain_tree_cli_next(bs1770gain_tree_t *tree,
    const bs1770gain_options_t *options)
{
  char *path;

  while (tree->cli.optind<tree->cli.argc) {
    path=tree->cli.argv[tree->cli.optind++];

    if (0<bs1770gain_tree_stat(tree,path,options))
      return tree->state;
  }

  return BS1770GAIN_TREE_STATE_INV;
}

///////////////////////////////////////////////////////////////////////////////
const bs1770gain_tree_vmt_t *bs1770gain_tree_dir_vmt(void)
{
  static bs1770gain_tree_vmt_t vmt;

  if (NULL==vmt.cleanup) {
    vmt.cleanup=bs1770gain_tree_dir_cleanup;
    vmt.next=bs1770gain_tree_dir_next;
  }

  return &vmt;
};

bs1770gain_tree_t *bs1770gain_tree_dir_init(bs1770gain_tree_t *tree,
    bs1770gain_tree_t *cli, const bs1770gain_tree_t *parent,
    const char *root)
{
#if defined (_WIN32) // {
  wchar_t *wroot;
#endif // }

  bs1770gain_tree_init(tree,bs1770gain_tree_dir_vmt(),cli,parent);
  tree->dir.root=root;
  tree->dir.path=NULL;

#if defined (_WIN32) // {
  if (NULL==(wroot=pbu_s2w(root))) {
    DMESSAGE("converting string");
    goto s2w;
  }

  if (NULL==(tree->dir.d=_wopendir(wroot))) {
    DMESSAGE("opening directory");
    goto dir;
  }

  free(wroot);
#else // } {
  if (NULL==(tree->dir.d=opendir(root))) {
    DMESSAGE("opening directory");
    goto dir;
  }
#endif // }

  return tree;
dir:
#if defined (_WIN32) // {
  free(wroot);
s2w:
#endif // }
  return NULL;
}

void bs1770gain_tree_dir_cleanup(bs1770gain_tree_t *tree)
{
  bs1770gain_tree_free_path(tree);
  CLOSEDIR(tree->dir.d);
}

int bs1770gain_tree_dir_next(bs1770gain_tree_t *tree,
    const bs1770gain_options_t *options)
{
#if defined (_WIN32) // {
  struct _wdirent *e;
#else // } {
  struct dirent *e;
#endif // }
  char *d_name;

  bs1770gain_tree_free_path(tree);

  while (NULL!=(e=READDIR(tree->dir.d))) {
#if defined (_WIN32) // {
    if (NULL==(d_name=pbu_w2s(e->d_name))) {
      DMESSAGE("converting string");
      goto invalid;
    }
#else // } {
    d_name=e->d_name;
#endif // }
    if (0==strcmp(".",d_name)||0==strcmp("..",d_name))
      goto next;
    else if (NULL==(tree->dir.path=pbu_extend_path(tree->dir.root,d_name)))
      goto next;
    else if (0<bs1770gain_tree_stat(tree,tree->dir.path,options)) {
#if defined (_WIN32) // {
      free(d_name);
#endif // }
      return tree->state;
    }

    bs1770gain_tree_free_path(tree);
  next:
#if defined (_WIN32) // {
    free(d_name);
#else // } {
    ;
#endif // }
  }

#if defined (_WIN32) // {
invalid:
#endif // }
  return BS1770GAIN_TREE_STATE_INV;
}

void bs1770gain_tree_free_path(bs1770gain_tree_t *tree)
{
  if (NULL!=tree->dir.path) {
    FREE(tree->dir.path);
    tree->dir.path=NULL;
    tree->basename=NULL;
    tree->path=NULL;
    tree->state=BS1770GAIN_TREE_STATE_INV;
  }
}
