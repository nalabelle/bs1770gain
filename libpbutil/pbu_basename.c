/*
 * pbu_basename.c
 * Copyright (C) 2014 Peter Belkner <pbelkner@users.sf.net>
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
#include <pbutil.h>

const char *pbu_basename(const char *path)
{
  const char *p;

  if (NULL==path)
    return NULL;

  p=path+strlen(path);

  // TODO: unicode.
  while (path<p&&('/'==p[-1]||'\\'==p[-1]))
    --p;

  // TODO: unicode.
  while (path<p&&('/'!=p[-1]&&'\\'!=p[-1]))
    --p;

  return p;
}

#if defined (_WIN32) // [
const wchar_t *pbu_wbasename(const wchar_t *wpath)
{
  const wchar_t *p;

  if (NULL==wpath)
    return NULL;

  p=wpath+wcslen(wpath);

  // TODO: unicode.
  while (wpath<p&&('/'==p[-1]||'\\'==p[-1]))
    --p;

  // TODO: unicode.
  while (wpath<p&&('/'!=p[-1]&&'\\'!=p[-1]))
    --p;

  return p;
}
#endif // ]
