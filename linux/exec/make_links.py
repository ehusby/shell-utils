#!/usr/bin/env python

# Erik Husby, 2018


import argparse
import glob
import os
import platform
import subprocess
import sys


global ARGV
PYTHON_EXE = 'python'


###### DO NOT MODIFY ######
FLIST_PREFIX = None
FLIST_CONTAINS = None
FLIST_SUFFIX = None
LINK_TYPE_HARDLINK = 0
LINK_TYPE_SYMLINK = 1
DRYRUN = False
SILENT = False
CMD_RAW = None
###########################


###### SET ARG DEFAULTS ######
SRC = r""
DSTDIR = r""
FLIST_SRCDIR = r""
DELIM = '|'  # CANNOT BE '>'
FNAME_PREFIX = ""
DNAME_PREFIX = ""
FNAME_CONTAINS = ""
DNAME_CONTAINS = ""
FNAME_SUFFIX = ""
DNAME_SUFFIX = ""
FNAME_REPLACE = ""
DNAME_REPLACE = ""
FLIST_GLOB = False
DEPTH_LIMIT = 'inf'
TRANSPLANT_TREE = False
COLLAPSE_TREE = False
OVERWRITE = False
LINK_TYPE = LINK_TYPE_HARDLINK
##############################


###### SET EXCLUSIONS ######
EXCLUDE_DNAMES = [
    "",
]
EXCLUDE_FNAMES = [
    "",
]
# NOTE: The following must be absolute paths.
EXCLUDE_DPATHS = [
    r"",
]
EXCLUDE_FPATHS = [
    r"",
]
############################

EXCLUDE_DNAMES, EXCLUDE_FNAMES = [
    exclude_names if exclude_names != [''] else None for exclude_names in (
        EXCLUDE_DNAMES, EXCLUDE_FNAMES,
    )
]
EXCLUDE_DPATHS, EXCLUDE_FPATHS = [
    [os.path.abspath(os.path.expanduser(path)) for path in exclude_paths] if exclude_paths != [''] else None for exclude_paths in (
        EXCLUDE_DPATHS, EXCLUDE_FPATHS
    )
]

default_src = SRC if SRC is not None and SRC != '' else None
default_dstdir = DSTDIR if DSTDIR is not None and DSTDIR != '' else None
default_flist_srcdir = FLIST_SRCDIR if FLIST_SRCDIR is not None and FLIST_SRCDIR != '' else None
default_depth = str(DEPTH_LIMIT)
default_hardlink = True if LINK_TYPE == LINK_TYPE_HARDLINK else False
default_symlink = True if LINK_TYPE == LINK_TYPE_SYMLINK else False
default_delim = DELIM
default_transplant_tree = TRANSPLANT_TREE
default_collapse_tree = COLLAPSE_TREE
default_flist_glob = FLIST_GLOB
default_overwrite = OVERWRITE
default_dryrun = DRYRUN
default_silent = SILENT

default_fprefix = FNAME_PREFIX if FNAME_PREFIX is not None and FNAME_PREFIX != '' else None
default_dprefix = DNAME_PREFIX if DNAME_PREFIX is not None and DNAME_PREFIX != '' else None
default_fcontains = FNAME_CONTAINS if FNAME_CONTAINS is not None and FNAME_CONTAINS != '' else None
default_dcontains = DNAME_CONTAINS if DNAME_CONTAINS is not None and DNAME_CONTAINS != '' else None
default_fsuffix = FNAME_SUFFIX if FNAME_SUFFIX is not None and FNAME_SUFFIX != '' else None
default_dsuffix = DNAME_SUFFIX if DNAME_SUFFIX is not None and DNAME_SUFFIX != '' else None
default_freplace = FNAME_REPLACE if FNAME_REPLACE is not None and FNAME_REPLACE != '' else None
default_dreplace = DNAME_REPLACE if DNAME_REPLACE is not None and DNAME_REPLACE != '' else None


class SystemSupportError(Exception):
    def __init__(self, msg=""):
        super(Exception, self).__init__(msg)


def main():
    parser = argparse.ArgumentParser(description=(
        "Clone a file tree with links (recursively), "
        "or get more specification by using a file/dir list text file of source paths."))

    parser.add_argument('--hardlink', action='store_true', default=default_hardlink,
        help=("Create hard links."
              +" (default)"*default_hardlink))

    parser.add_argument('--symlink', action='store_true', default=default_symlink,
        help=("Create symbolic links."
              +" (default)"*default_symlink))

    parser.add_argument('--src', default=default_src,
        help=("Path to source directory containing files to link to, "
              "or path to a text file containing a list of files to link to. "
              "If `src` is a file/dir list, these should be absolute paths unless "
              "--flist-srcdir option is used. Any directory entries in this list "
              "MUST end with a '/'. "
              "\nThe target destination directory of a particular entry can be "
              "specified on the same line as the source file/dir path like "
              "'[src file/dir path]{}[dst dir path]'. [dst dir path] can be either absolute "
              "(starts with '/' in Linux or '[A-Z]:' in Windows) or relative to the provided "
              "`dst` destination directory.".format(default_delim)
              +" (default={})".format(default_src)*(default_src is not None)))

    parser.add_argument('--dst', default=default_dstdir,
        help=("Path to destination directory where file tree of links will be created. "
              "If `src` is a file/dir list, all linked files/dirs are put directly in this folder."
              +" (default={})".format(default_dstdir)*(default_dstdir is not None)))

    parser.add_argument('--depth', default=default_depth,
        help=("Depth of recursion, in terms of directory levels below the level of the root. "
              "Value of 0 will link only files in `src` directory. Value of 'inf' (sans quotes) "
              "will traverse the whole directory tree."
              " (default={})".format(default_depth)))

    parser.add_argument('--transplant-tree', action='store_true', default=default_transplant_tree,
        help=("(Only applies when `src` is a directory path.) "
              "Create the link file tree within the root folder `dst`/`basename(abspath(src))`. "
              "If false, create the link file tree within `dst`, more like a sync."
              " (default={})".format(default_transplant_tree)))

    parser.add_argument('--collapse-tree', action='store_true', default=default_collapse_tree,
        help=("(Only applies when `src` is a directory or a dir list.) "
              "Skip recreating the folder structure of the source file tree in the "
              "destination directory and instead create all links in the top level "
              "of the destination directory."
              " (default={})".format(default_collapse_tree)))

    parser.add_argument('--flist-srcdir', default=default_flist_srcdir,
        help=("If `src` is a file/dir list, prepend this directory to all "
              "source file entries before processing."
              +" (default={})".format(default_flist_srcdir)*(default_flist_srcdir is not None)))

    parser.add_argument('--flist-glob', action='store_true', default=default_flist_glob,
        help=("If `src` is a file/dir list, use Unix-style pathname pattern expansion "
              "for instances of '*', '?', and character ranges '[]'."
              " (default={})".format(default_flist_glob)))

    parser.add_argument('--delim', default=default_delim,
        help=("Deliminating character for multiple --[d/f][prefix/contains/suffix] specification. "
              " (default={})".format(default_delim)))

    parser.add_argument('--fprefix', default=default_fprefix,
        help=("Only include files with a name that starts with this string. "
              "If `src` is a file list with filenames like qsub_*, syntax can be like "
              "'qsub_>' to link files without the qsub_ prefix."
              +" (default={})".format(default_fprefix)*(default_fprefix is not None)))

    parser.add_argument('--fcontains', default=default_fcontains,
        help=("Only include files with a name that contains this string. "
              "If `src` is a file list with filenames like *_2m_*, syntax can be like "
              "'_2m_>_2m_{}_8m_' to link additional *_8m_* component files.".format(default_delim)
              +" (default={})".format(default_fcontains)*(default_fcontains is not None)))

    parser.add_argument('--fsuffix', default=default_fsuffix,
        help=("Only include files with a name that ends with this string. "
              "If `src` is a file list of .ntf files, syntax can be like "
              "'.ntf>.ntf{}.xml' to link additional .xml component files. "
              "If `src` is a file list of strip ID filename prefixes like "
              "WV01_20140421_102001002DD3BF00_102001002DCB4E00_, syntax can be like "
              "'>*' along with --flist-glob option to link all component files.".format(default_delim)
              +" (default={})".format(default_fsuffix)*(default_fsuffix is not None)))

    parser.add_argument('--freplace', default=default_freplace,
        help=("Replace all instances of a (set of) substring(s) in filenames, "
              "syntax like 'ss1_orig>ss1_repl{}ss2_orig>ss2_repl' where "
              "replacements are evaluated left to right in overwriting fashion.".format(default_delim)
              +" (default={})".format(default_freplace)*(default_freplace is not None)))

    parser.add_argument('--dprefix', default=default_dprefix,
        help=("Only include directories with a name that starts with this string."
              +" (default={})".format(default_dprefix)*(default_dprefix is not None)))

    parser.add_argument('--dcontains', default=default_dcontains,
        help=("Only include directories with a name that contains this string."
              +" (default={})".format(default_dcontains)*(default_dcontains is not None)))

    parser.add_argument('--dsuffix', default=default_dsuffix,
        help=("Only include directories with a name that ends with this string."
              +" (default={})".format(default_dsuffix)*(default_dsuffix is not None)))

    parser.add_argument('--dreplace', default=default_dreplace,
        help=("Replace all instances of a (set of) substring(s) in directory names, "
              "syntax like 'ss1_orig>ss1_repl{}ss2_orig>ss2_repl' where "
              "replacements are evaluated left to right in overwriting fashion. "
              "*Only applies when `src` is a directory or a dir list.*".format(default_delim)
              +" (default={})".format(default_dreplace)*(default_dreplace is not None)))

    parser.add_argument('--overwrite', action='store_true', default=default_overwrite,
        help=("If a file already exists at the path where the link is to be created "
              "and it appears to `filecmp.cmp()` that the existing file is not already "
              "a link to the source file, remove the existing file and create the link."
              " (default={})".format(default_overwrite)))

    parser.add_argument('--silent', action='store_true', default=default_silent,
        help="Do not print all actions.")

    parser.add_argument('--dryrun', action='store_true', default=default_dryrun,
        help="Print actions without executing.")

    system_choices = ('Windows', 'Linux')
    system = platform.system()
    python_version = platform.python_version()
    if system not in system_choices:
        parser.error("Only supported system types are {}, "
                     "but detected '{}'".format(system_choices, system))

    global FLIST_SRCDIR, FLIST_GLOB
    global GLOB_PREFIX, GLOB_SUFFIX
    global FLIST_PREFIX, FLIST_CONTAINS, FLIST_SUFFIX
    global FNAME_PREFIX, FNAME_CONTAINS, FNAME_SUFFIX, FNAME_REPLACE
    global DNAME_PREFIX, DNAME_CONTAINS, DNAME_SUFFIX, DNAME_REPLACE
    global DEPTH_LIMIT, COLLAPSE_TREE, TRANSPLANT_TREE
    global CMD_RAW, LINK_FUNCTION, OVERWRITE, DRYRUN, VERBOSE
    global ARGV, DELIM

    ARGV = sys.argv

    # Parse arguments.
    args = parser.parse_args()
    if args.src is None or args.dst is None:
        parser.error("`src` and `dst` must both be specified")
    SRC = os.path.abspath(os.path.expanduser(args.src))
    DSTDIR = os.path.abspath(os.path.expanduser(args.dst))
    FLIST_SRCDIR = os.path.abspath(os.path.expanduser(args.flist_srcdir)) if args.flist_srcdir is not None else None
    DELIM = args.delim
    FNAME_PREFIX, DNAME_PREFIX, \
    FNAME_CONTAINS, DNAME_CONTAINS, \
    FNAME_SUFFIX, DNAME_SUFFIX, \
    FNAME_REPLACE, DNAME_REPLACE = [
        s.split(DELIM) if s is not None else None for s in (
            args.fprefix, args.dprefix,
            args.fcontains, args.dcontains,
            args.fsuffix, args.dsuffix,
            args.freplace, args.dreplace
        )
    ]
    FLIST_GLOB = args.flist_glob
    TRANSPLANT_TREE = args.transplant_tree
    COLLAPSE_TREE = args.collapse_tree
    if args.depth.isdigit():
        DEPTH_LIMIT = int(args.depth)
    elif args.depth.lower() == 'inf':
        DEPTH_LIMIT = float(args.depth)
    else:
        parser.error("`depth` must be 'inf' (sans quotes) or a positive integer")
    OVERWRITE = args.overwrite
    DRYRUN = args.dryrun
    VERBOSE = (not args.silent)

    if FNAME_PREFIX is not None and '>' in FNAME_PREFIX[0]:
        FLIST_PREFIX, FNAME_PREFIX[0] = FNAME_PREFIX[0].split('>')
    if FNAME_CONTAINS is not None and '>' in FNAME_CONTAINS[0]:
        FLIST_CONTAINS, FNAME_CONTAINS[0] = FNAME_CONTAINS[0].split('>')
    if FNAME_SUFFIX is not None and '>' in FNAME_SUFFIX[0]:
        FLIST_SUFFIX, FNAME_SUFFIX[0] = FNAME_SUFFIX[0].split('>')

    if FLIST_GLOB:
        glob_chars = ['*', '?']
        GLOB_PREFIX = ''
        GLOB_SUFFIX = ''
        if FNAME_PREFIX is not None and len(FNAME_PREFIX) == 1:
            for char in glob_chars:
                if char in FNAME_PREFIX[0]:
                    GLOB_PREFIX = FNAME_PREFIX[0]
                    FNAME_PREFIX = None
                    break
        if FNAME_SUFFIX is not None and len(FNAME_SUFFIX) == 1:
            for char in glob_chars:
                if char in FNAME_SUFFIX[0]:
                    GLOB_SUFFIX = FNAME_SUFFIX[0]
                    FNAME_SUFFIX = None
                    break

    if FNAME_REPLACE is not None:
        for i, repl_str in enumerate(FNAME_REPLACE):
            if '>' not in repl_str:
                parser.error("--freplace argument must contain '>'")
            FNAME_REPLACE[i] = repl_str.split('>')
    if DNAME_REPLACE is not None:
        for i, repl_str in enumerate(DNAME_REPLACE):
            if '>' not in repl_str:
                parser.error("--dreplace argument must contain '>'")
            DNAME_REPLACE[i] = repl_str.split('>')

    # Validate arguments.
    if os.path.isdir(SRC):
        if [flist_arg is not None for flist_arg in (FLIST_PREFIX, FLIST_CONTAINS, FLIST_SUFFIX)].count(True) > 0:
            parser.error("`src` must be a text file to use extension of "
                         "source files in file list via '>'")
    elif os.path.isfile(SRC) and SRC.endswith('.txt'):
        if [flist_arg is not None for flist_arg in (FLIST_PREFIX, FLIST_CONTAINS, FLIST_SUFFIX)].count(True) > 1:
            parser.error("Only one of (--fprefix, --fcontains, --fsuffix) options "
                         "may be used for extension of source files in file list via '>'")
    else:
        parser.error("`src` must be a directory or text file")
    if FLIST_SRCDIR is not None and not os.path.isdir(FLIST_SRCDIR):
        parser.error("--flist-srcdir is not a valid directory")
    if not (args.hardlink or args.symlink):
        parser.error("One of --hardlink and --symlink options must be specified")
    if args.hardlink and args.symlink:
        parser.error("--hardlink and --symlink options are mutually exclusive")

    LINK_FUNCTION = None
    try:
        if args.hardlink:
            LINK_FUNCTION = os.link
        elif args.symlink:
            LINK_FUNCTION = os.symlink
    except AttributeError:
        print("Python built-in link function is not available "
              "on this system ({}) and/or Python version ({})".format(system, python_version))
        print("Falling back to external calls to system-level link command")
    # Set syntax of linking command, to be evaluated before execution.
    CMD_RAW = get_cmd(system, args)

    if not os.path.isdir(DSTDIR) and not DRYRUN:
        os.makedirs(DSTDIR)

    if os.path.isdir(SRC):
        if TRANSPLANT_TREE:
            link_rootdir_name = os.path.basename(os.path.abspath(SRC))
            if DNAME_REPLACE is not None:
                for repl_item in DNAME_REPLACE:
                    link_rootdir_name = link_rootdir_name.replace(repl_item[0], repl_item[1])
            link_rootdir = os.path.join(DSTDIR, link_rootdir_name)
            if not os.path.isdir(link_rootdir) and not DRYRUN:
                os.makedirs(link_rootdir)
            DSTDIR = link_rootdir
        link_dir(SRC, DSTDIR, 0)

    elif os.path.isfile(SRC):
        link_flist(SRC, DSTDIR)


def get_cmd(systype, args):
    cmd = None

    if systype == 'Windows':
        if args.hardlink:
            cmd = r"r'mklink /h {0} {1}'.format(dst_file, src_file)"
        elif args.symlink:
            cmd = r"r'mklink {0} {1}'.format(dst_file, src_file)"

    elif systype == 'Linux':
        if args.hardlink:
            cmd = r"r'ln {0} {1}'.format(src_file, dst_file)"
        elif args.symlink:
            cmd = r"r'ln -s {0} {1}'.format(src_file, dst_file)"

    elif LINK_FUNCTION is not None:
        if args.hardlink:
            cmd = r"r'Linking using built-in function: os.link({0} {1})'.format(src_file, dst_file)"
        elif args.symlink:
            cmd = r"r'Linking using built-in function: os.symlink({0} {1})'.format(src_file, dst_file)"

    else:
        raise SystemSupportError("Detected system type '{}' is not supported")

    return cmd


def link_file(src_file, dst_file):
  
    if os.path.isfile(dst_file):
        if os.stat(src_file).st_ino == os.stat(dst_file).st_ino:
            if VERBOSE:
                print("Correct link already exists: {}".format(dst_file))
            return
        else:
            if VERBOSE:
                print("File already exists, but is not the correct link and will be {}: {}".format(
                  "overwritten" if OVERWRITE else "skipped", dst_file))
            if OVERWRITE:
                os.remove(dst_file)
            else:
                return

    if LINK_FUNCTION is None or DRYRUN or VERBOSE:
        cmd = eval(CMD_RAW)
        if DRYRUN or VERBOSE:
            # print(cmd)
            print("LINKING: {} --> {}".format(src_file, dst_file))
    if not DRYRUN:
        if LINK_FUNCTION is not None:
            LINK_FUNCTION(src_file, dst_file)
        else:
            subprocess.call(cmd, shell=True)


def link_dir(srcdir, dstdir, depth):

    for dirent in os.listdir(srcdir):
        src_dirent = os.path.join(srcdir, dirent)

        name_replacements = DNAME_REPLACE if os.path.isdir(src_dirent) else FNAME_REPLACE
        dst_dirent_name = dirent
        if name_replacements is not None:
            for repl_item in name_replacements:
                dst_dirent_name = dst_dirent_name.replace(repl_item[0], repl_item[1])
        dst_dirent = os.path.join(dstdir, dst_dirent_name)

        if os.path.isdir(src_dirent):
            if (    depth < DEPTH_LIMIT
                and (EXCLUDE_DNAMES is None or dirent not in EXCLUDE_DNAMES)
                and (EXCLUDE_DPATHS is None or src_dirent not in EXCLUDE_DPATHS)
                and (DNAME_PREFIX is None or True in (dirent.startswith(dp) for dp in DNAME_PREFIX))
                and (DNAME_CONTAINS is None or True in (dc in dirent for dc in DNAME_CONTAINS))
                and (DNAME_SUFFIX is None or True in (dirent.endswith(ds) for ds in DNAME_SUFFIX))):
                # The directory entry is a subdirectory to traverse.
                if COLLAPSE_TREE:
                    dst_dirent = dstdir
                elif not os.path.isdir(dst_dirent) and not DRYRUN:
                    os.makedirs(dst_dirent)
                link_dir(src_dirent, dst_dirent, depth+1)

        else:
            if (    (EXCLUDE_FNAMES is None or dirent not in EXCLUDE_FNAMES)
                and (EXCLUDE_FPATHS is None or src_dirent not in EXCLUDE_FPATHS)
                and (FNAME_PREFIX is None or True in (dirent.startswith(fp) for fp in FNAME_PREFIX))
                and (FNAME_CONTAINS is None or True in (fc in dirent for fc in FNAME_CONTAINS))
                and (FNAME_SUFFIX is None or True in (dirent.endswith(fs) for fs in FNAME_SUFFIX))):
                # The directory entry is a file to link.
                link_file(src_dirent, dst_dirent)


def link_flist(flist, dstdir):
    dstdir_orig = dstdir

    with open(flist, 'r') as flist_fp:

        for line_num, line in enumerate(flist_fp):
            flist_item = line.strip()
            if flist_item == '':
                continue

            if DELIM in flist_item:
                txt_fpath, txt_dname = [s.strip() for s in flist_item.split(DELIM)]
                if not (txt_dname.startswith('/') or txt_dname[1] == ':'): # if path is not absolute
                    dstdir = os.path.join(dstdir_orig, txt_dname)
            else:
                txt_fpath = flist_item

            if FLIST_SRCDIR is not None:
                if not txt_fpath.startswith(FLIST_SRCDIR):
                    txt_fpath = os.path.join(FLIST_SRCDIR, txt_fpath)

            txt_dpath, txt_fname = os.path.split(txt_fpath)
            txt_dname = os.path.basename(txt_dpath)

            if (    (EXCLUDE_DNAMES is None or txt_dname not in EXCLUDE_DNAMES)
                and (EXCLUDE_DPATHS is None or txt_dpath not in EXCLUDE_DPATHS)
                and (DNAME_PREFIX is None or True in (txt_dname.startswith(dp) for dp in DNAME_PREFIX))
                and (DNAME_CONTAINS is None or True in (dc in txt_dname for dc in DNAME_CONTAINS))
                and (DNAME_SUFFIX is None or True in (txt_dname.endswith(ds) for ds in DNAME_SUFFIX))):
                pass
            else:
                continue

            if txt_fname == '':
                src_dirs = [txt_dpath]
                if FLIST_GLOB:
                    src_dirs_glob = []
                    for dir_pattern in src_dirs:
                        src_dirs_glob.extend([d for d in glob.glob(dir_pattern) if os.path.isdir(d)])
                    src_dirs = src_dirs_glob
                    if EXCLUDE_DPATHS is not None:
                        src_dirs = [d for d in src_dirs if d not in EXCLUDE_DPATHS]
                    if not src_dirs_glob:
                        print("Glob for directory path pattern '{}' returned 0 matching directories".format(dir_pattern))
                for d in src_dirs:
                    # argv_dir = list(ARGV)
                    # argv_dir[argv_dir.index('--src') + 1] = d
                    # argv_dir[argv_dir.index('--dst') + 1] = dstdir
                    # if '--transplant-tree' not in argv_dir:
                    #     argv_dir.append('--transplant-tree')
                    # cmd = '{} {}'.format(PYTHON_EXE, ' '.join(argv_dir)) if argv_dir[0].endswith('.py') else ' '.join(argv_dir)
                    # if DRYRUN:
                    #     print(cmd)
                    # subprocess.call(cmd, shell=True)
                    if not os.path.isdir(d):
                        print("Source file list line {}: "
                          "Missing source directory '{}', skipping".format(line_num+1, d))
                        continue
                    if TRANSPLANT_TREE:
                        link_rootdir_name = os.path.basename(os.path.normpath(os.path.abspath(d)))
                        if DNAME_REPLACE is not None:
                            for repl_item in DNAME_REPLACE:
                                link_rootdir_name = link_rootdir_name.replace(repl_item[0], repl_item[1])
                        link_rootdir = os.path.join(dstdir, link_rootdir_name)
                        if not os.path.isdir(link_rootdir) and not DRYRUN:
                            os.makedirs(link_rootdir)
                    else:
                        link_rootdir = dstdir
                    link_dir(d, link_rootdir, 0)
                continue

            if FLIST_PREFIX is not None:
                repl_index = txt_fname.find(FLIST_PREFIX)
                if repl_index == -1:
                    print("Could not find file name prefix '{}' "
                          "in source file list line {}: {}".format(FLIST_PREFIX, line_num+1, txt_fpath))
                    continue
                txt_fname_suff = txt_fname[repl_index+len(FLIST_PREFIX):]
                if FNAME_PREFIX is not None:
                    src_fnames = [link_pref+txt_fname_suff for link_pref in FNAME_PREFIX]
                else:
                    src_fnames = [txt_fname_suff]

            elif FLIST_SUFFIX is not None:
                repl_index = txt_fname.rfind(FLIST_SUFFIX)
                if repl_index == -1:
                    print("Could not find file name suffix '{}' "
                          "in source file list line {}: {}".format(FLIST_SUFFIX, line_num+1, txt_fpath))
                    continue
                txt_fname_pref = txt_fname[:repl_index]
                if FNAME_SUFFIX is not None:
                    src_fnames = [txt_fname_pref+link_suff for link_suff in FNAME_SUFFIX]
                else:
                    src_fnames = [txt_fname_pref]

            elif FLIST_CONTAINS is not None:
                src_fnames = [txt_fname.replace(FLIST_CONTAINS, link_cont) for link_cont in FNAME_CONTAINS]

            else:
                src_fnames = [txt_fname]

            if FLIST_GLOB or EXCLUDE_FPATHS is not None:
                if FLIST_GLOB:
                    src_files = []
                    for file_pattern in [os.path.join(txt_dpath, GLOB_PREFIX+fname+GLOB_SUFFIX) for fname in src_fnames]:
                        src_files_glob = glob.glob(file_pattern)
                        if not src_files_glob:
                            print("Glob for file path pattern '{}' returned 0 matching files".format(file_pattern))
                        else:
                            src_files.extend(src_files_glob)
                else:
                    src_files = [os.path.join(txt_dpath, fname) for fname in src_fnames]
                if EXCLUDE_FPATHS is not None:
                    src_files = [f for f in src_files if f not in EXCLUDE_FPATHS]
                src_fnames = [os.path.basename(f) for f in src_files]

            src_files = [os.path.join(txt_dpath, src_fname) for src_fname in src_fnames if (
                    (EXCLUDE_FNAMES is None or src_fname not in EXCLUDE_FNAMES)
                and (FNAME_PREFIX is None or FLIST_PREFIX is not None or True in (src_fname.startswith(fp) for fp in FNAME_PREFIX))
                and (FNAME_CONTAINS is None or FLIST_CONTAINS is not None or True in (fc in src_fname for fc in FNAME_CONTAINS))
                and (FNAME_SUFFIX is None or FLIST_SUFFIX is not None or True in (src_fname.endswith(fs) for fs in FNAME_SUFFIX))
            )]
            if len(src_files) == 0:
                continue

            missing_component = False
            for f in src_files:
                if not os.path.isfile(f):
                    missing_component = True
                    print("Source file list line {}: "
                          "Missing source file component '{}'".format(line_num+1, f))
            if missing_component:
                print("Source file list line {}: "
                      "Skipping source file '{}' due to missing component".format(line_num+1, txt_fpath))
                continue

            for src_dirent in src_files:
                if not os.path.isfile(src_dirent):
                    continue

                dst_dirent_name = os.path.basename(src_dirent)
                if FNAME_REPLACE is not None:
                    for repl_item in FNAME_REPLACE:
                        dst_dirent_name = dst_dirent_name.replace(repl_item[0], repl_item[1])
                dst_dirent = os.path.join(dstdir, dst_dirent_name)

                link_file(src_dirent, dst_dirent)



if __name__ == '__main__':
    main()
