# Script for helper-functions, as used on EmilMisc-package
# readline_time(prompt, timeout = 3600, precision=.1): Readline with waiting limit ----
#' Readline with waiting limit
#'
#' Normally, when using readline, execution is halted until input is supplied, and if it is not, the script hangs forever
#' This functions waits a set time for the user to provide input, then returns control
#'
#' @param prompt prompt for the user, similar to the one in readline(). Usually ends with a space (or newline).
#' @param timeout timer in seconds. If set to 0, base::readline is used
#' @param precision Polling interval in seconds. \cr
#' Internally, every \code{precision} seconds the script checks if valid input is received.
#' Smaller values increase responsiveness, but also increase CPU-usage.
#' @return Input provided by the user, if provided in time (and finished with RETURN)\cr
#' If the timer has expired, \code{character(0)}, even if the user has started typing but has not yet pressed RETURN.
#' If used in a non-interactive session, NULL, and if the timer has expired, character(0).\cr
#' If timeout==0, the same as provided by readline()
#' @note Unfortunately, does not work on all platforms/in all environments.\cr
#' It is dependent on being able to read from file('stdin'), which is different from stdin(), see \code{\link[base]{file}} for details.
#' In particular, it does not work in RStudio for MacOS, or Rgui for Windows or MacOS.
#' It does confirmed work on R run from terminal on MacOS 10.13.6\cr
#' Problems manifest by file('stdin') not being connected to anything, i.e. no input is received, so this function always returns \code{character(0)},
#' and any input typed is interpreted as a new command. To test, try with a small value of timeout first.
#' @seealso \code{\link{waitForKey}} for a function that simply waits for a keypress for a set time.
#' @export
readline_time <- function(prompt, timeout = 3600, precision=.1) {
  stopifnot(length(prompt)<=1,
            is.numeric(timeout),
            length(timeout)==1,
            !is.na(timeout),
            timeout>=0,
            is.numeric(precision),
            length(precision)==1,
            !is.na(precision),
            precision>0)
  if(!interactive()) return(NULL)
  if(timeout==0) return(readline(prompt))
  timer <- timeout
  my_in <- file('stdin')
  open(my_in, blocking=FALSE)
  cat(prompt)
  ans <- readLines(my_in, n=1)
  while(timer>0 && !length(ans)) {
    Sys.sleep(precision)
    timer <- timer-precision
    ans <- readLines(my_in, n=1)
  }
  close(my_in)
  return(ans)
}


# waitForKey(message, time=10, counter=.5, precision=.01): Wait for set time, or continue on input. ----
#' Wait for set time, or continue on input.
#'
#' Waits until a timer has expired, or the user has provided some input (pressed RETURN)\cr
#' A message is shown, with a countdown-timer if desired.
#' @param message Message to be shown during countdown. Use {n} as a placeholder for the number of seconds left.
#' @param time Time to wait, in seconds (approximate)
#' @param counter Interval to update the message, in seconds. 0 to remain static. Must otherwise be a multiple of precision to work reliably.
#' @param precision Polling interval to use when checking for a keypress.
#' @return (invisibly) Either the string 'key' or 'timer', signifying what caused the return
#' @note Unfortunately, does not work on all platforms/in all environments.\cr
#' It is dependent on being able to read from file('stdin'), which is different from stdin(), see \code{\link[base]{file}} for details.
#' In particular, it does not work in RStudio for MacOS, or Rgui for Windows or MacOS.
#' It does confirmed work on R run from terminal on MacOS 10.13.6\cr
#' Problems manifest by file('stdin') not being connected to anything, i.e. no input is received, so this function always returns \code{character(0)},
#' and any input typed is interpreted as a new command. To test, try with a small value of time first.
#' @seealso \code{\link{readline_time}} for a function that also collects your input.
#' @export
waitForKey <- function(message='Continuing in {n} seconds, or press any key.', time=10, counter=.5, precision=.01) {
  stopifnot(is.character(message), length(message)==1, !is.na(message),
            is.numeric(time), length(time)==1, !is.na(time), time>0,
            is.numeric(counter), length(counter)==1, !is.na(counter), counter>=0,
            is.numeric(precision), length(precision)==1, !is.na(precision), precision>0)
  my_in <- file('stdin')
  open(my_in, blocking=FALSE)
  ans <- readLines(my_in, n=1)
  if(counter==0) cat(message)
  while(time>0 && !length(ans)) {
    if(counter>0 && !is.null(message) && round(time/counter, digits = 3) %% 1L==0L) {
      cat(gsub('\\{n\\}', format(round(time, digits=4), width=5, scientific = F), message), '\r', sep = '')
    }
    Sys.sleep(precision)
    time <- time-precision
    ans <- readLines(my_in, n=1)
  }
  close(my_in)
  if(length(ans)) {
    return(invisible('key'))
  } else {
    return(invisible('timer'))
  }
}


# libinstandload(): Library Auto-installation and loading ----
#' Library Auto-installation and loading
#'
#' One combined function to load (multiple) packages, and automatically install them if needed
#' @param ... list of packages to install
#' @param order logical specifying whether packages should be loaded in order. If TRUE, first argument is loaded first (so comes last in search())
#'     if FALSE, R tries to load packages first, then installs any misses, so new packages are on top. FALSE is slightly faster
#' @param verbose logical, whether to print messages from require and install.package
#' @param extras logical. Some packages need extra initialization, e.g. extrafonts needs to install fonts. Should extra initializations be done on installation?\cr
#'     Note that initiliazation scripts are added on an ad-hoc basis, and is not complete. In this first version. it is only implemented for 'extrafont'
#' @export
libinstandload <- function(..., order=FALSE, verbose=FALSE, extras=TRUE) {
  packs <- list(...)
  if(!all(rapply(packs, class)=='character')) stop('Unexpected arguments, all args in ... should be character or list of characters')
  packs <- unlist(packs)
  if(extras) {
    if('extrafont' %in% packs) {
      if(length(tryCatch(find.package('extrafont'), error=function(e) {character()}))==0) {
        loadfonts <- importfonts <- TRUE
      } else if(!'package:extrafont' %in% search()) {
        importfonts <- FALSE
        loadfonts <- TRUE
      } else {
        loadfonts <- importfonts <- FALSE
      }
    }
  }
  if(order) {
    for(p in packs) {
      if(verbose && !require(p, character.only = TRUE)) {
        utils::install.packages(p)
        library(p, character.only=TRUE)
      } else if(!verbose && !suppressMessages(suppressWarnings(require(p, character.only = TRUE,quietly = TRUE)))) {
        suppressMessages(utils::install.packages(p))
        suppressMessages(library(p, character.only = T))
      }
    }
  } else {
    if(verbose) {
      install <- !sapply(packs, require, character.only=TRUE)
      if(any(install)) {
        utils::install.packages(unlist(packs[install]))
        sapply(packs[install], library, character.only=TRUE)
      }
    } else {
      install <- suppressMessages(suppressWarnings(!sapply(packs, require, character.only=TRUE, quietly=TRUE)))
      if(any(install)) {
        suppressMessages(utils::install.packages(unlist(packs[install])))
        suppressMessages(sapply(packs[install], library, character.only=TRUE))
      }
    }
  }
  if(extras) {
    if('extrafont' %in% packs) {
      if(importfonts) extrafont::font_import(prompt=verbose)
      if(loadfonts) {
        if(verbose) {
          loadfonts()
          loadfonts(device='postscript')
        } else {
          suppressMessages(loadfonts())
          suppressMessages(loadfonts(device='postscript'))
        }
      }
    }
  }
  return(invisible(0))
}

# simple_rapply(x, fn, ..., classes='ANY', inclLists='No'): Alternative for rapply ----
#' Alternative for rapply
#'
#' Function to be used as an alternative for rapply (recursive version of lapply)\cr
#' It differs in two important aspects:
#' \enumerate{
#' \item It handles NULL as a value, instead of seeing it as an empty list. See examples for comparison
#' \item If you set inclLists to TRUE, it also applies fn over the lists itself
#' }
#'
#' Further note that this implementation is comparable to running rapply with how='replace'
#' @param x Any object, but usually a list (if not a list, the result is identical to calling fn(x, ...))
#' @param fn A function to apply over the elements of x
#' @param ... Additional arguments passed on to fn
#' @param classes A character vector of class names, or "ANY" to match any class. Other classes are returned unmodified
#' @param inclLists Should fn be also applied to the lists themselves? see 'Examples'.
#' Can be FALSE, 'No', 'First', 'Last' or TRUE. First and Last apply fn to the list themselves either before or after applying to the elements themselves.
#' TRUE and FALSE are for backward compatibility, and are casted to 'No' and 'First', with a warning
#' @return a list with the same structure as x, with fn applied over the elements
#' @seealso rapply
#' @examples
#' L <- list(l=list(m=4, o=NULL, n=3), p=list(NULL), q=c(t=6, r=4,s=5), k=1)
#' rapply(L, is.null, how='replace')
#' any(unlist(rapply(L, is.null, how='replace')))
#' simple_rapply(L, is.null)
#' any(unlist(rapply(L, is.null)))
#'
#' rapply(L, function(x) {if(!is.null(names(x))) x[order(names(x))] else x}, how='replace')
#' simple_rapply(L, function(x) {if(!is.null(names(x))) x[order(names(x))] else x})
#' simple_rapply(L, function(x) {if(!is.null(names(x))) x[order(names(x))] else x}, inclLists=TRUE)
#' @export
simple_rapply <- function(x, fn, ..., classes='ANY', inclLists='No') {
  if(is.logical(inclLists)) {
    inclLists <- ifelse(inclLists, 'First', 'Last')
    warning('Argument inclLists is logical, which is deprecated. Use "No", "First" or "Last" instead.')
  }
  if(length(fn)>1 || length(inclLists)>1 || inclLists %!in% c('No','First','Last')) stop('Bad arguments')
  if(is.list(x))
  {
    if(inclLists=='First') x <- fn(x, ...)
    if(inclLists=='Last') {
      x <- lapply(x, simple_rapply, fn, ..., classes=classes, inclLists=inclLists) # Don't sapply this, return value must be consistent (thus list)
      return(fn(x,...))
    } else {
      return(lapply(x, simple_rapply, fn, ..., classes=classes, inclLists=inclLists)) # Don't sapply this, return value must be consistent (thus list)
    }
  } else {
    if(classes=='ANY' || class(x) %in% classes) {
      fn(x, ...)
    } else {
      x
    }
  }
}
# %!in%: Value not matching ----
#' Value not matching
#'
#' Simple function, element x is not in y.\cr
#' \code{x \%!in\% y} is the same as \code{!x \link[base]{\%in\%} y}\cr
#' Just implemented because I've found myself having to go back too often.
#'
#' @param x,y Used as in !(x \%in\% y)
#' @seealso \code{\link[base]{\%in\%}}
#'
#' @name not-in
#' @rdname not-in
#'
#' @export
`%!in%` <- function(x,y)!('%in%'(x,y))

# LazyAnd(a, b, fun, ...) and LazyOr: Lazy (short-circuited), vectorized &/&& and |/|| ----
#' Lazy (short-circuited), vectorized &/&& and |/||
#'
#' In base R, & is vectorized, and && is short-circuited (also called lazy evaluation).
#' LazyAnd combines these two: a is evaluated, and then fun(b) is called for the positions where a evaluates to TRUE (or NA), to decide a & b.
#' The advantage is that it's possible to check for valid inputs and use these inputs in one go, or that it's possible to only call an expensive function when needed.\cr\cr
#' LazyOr is analogous, fun(b) only called if a is FALSE or NA
#'
#' @param a A logical
#' @param b A vector equal to length of a (unless length(a)==1), which is used if a evaluates to TRUE or NA (for LazyAnd), or if a evaluates to FALSE or NA (for LazyOr)
#' @param fun Function to be called. Note that this function needs fun(b[x]) to be independent of fun(b[y])
#' @param ... Additional arguments to be passed on to fun
#'
#' @return
#' LazyAnd: \code{a & fun(b)}, but fun(b) is only called for those b[x] where \code{a[x]==TRUE || is.na(a[x])}\cr\cr
#' LazyOr: \code{a | fun(b)}, but fun(b) is only called for those b[x] where \code{a[x]==FALSE || is.na(a[x])}
#'
#' @section Warning:
#' Note that this may produce unexpected results if elements of fun(b) are not independent of each other, e.g. calling: \cr
#' \code{
#' nums <- 1:10
#' nums \%\% 2==0 & cumsum(nums) \%\% 2==0
#' }\cr\cr
#' and\cr\cr
#' \code{
#' LazyAnd(nums \%\% 2==0, nums, function(x) {cumsum(x) \%\% 2==0})
#' }\cr\cr
#' gives different results, as \code{cumsum(1:10[c(2,4,6,8,10)]}) is called, instead of \code{cumsum(1:10)[c(2,4,6,8,10)]}, which produces different results
#'
#' @examples
#' # A function to check evenness, but who prints an alert if the value is more then 10
#' input <- data.frame(valid=c(TRUE,TRUE,TRUE,TRUE,FALSE,FALSE),
#' value=c('1','12',2,'3','huh',14), stringsAsFactors = FALSE)
#' fun <- function(x) {
#'   if(any(as.numeric(x)>10))
#'     cat('Numbers over 10 (unexpected):',as.numeric(x)[as.numeric(x)>10], '')
#'   return(as.numeric(x) %% 2==0)
#' }
#' cat("\nAnd in total we have",sum(input$valid & fun(input$value)),"even numbers")
#' cat("\nWith LazyAnd we have in total:",sum(LazyAnd(input$valid, input$value, fun)),"even numbers")
#'
#' # Example where calling a function for all possible values would be possible,
#' # but (prohibitively) expensive
#' set.seed(4)
#' # This function may be very expensive, so we don't want to check all numbers
#' is.prime <- function(n) n == 2L || all(n %% 2L:max(2,floor(sqrt(n))) != 0)
#' n <- floor(runif(1e4, min=0, max=.5)^(-4))
#' surely_prime <- LazyAnd(n<1e10, n, sapply, FUN=is.prime)
#'
#' # The difference between this call and
#' \dontrun{sapply(n, is.prime) # Don't try this at home!}
#' # is getting results for 62 more occurences (with low probability of being prime,
#' # probably 2-3 of them are prime), at the cost of a LOT of resources.
#'
#' @export
LazyAnd <- function(a, b, fun, ...) {
  stopifnot(length(a)==1 || length(a)==length(b))
  a[is.na(a)|a] <- a[is.na(a)|a] & fun(b[is.na(a)|a], ...)
  return(a)
}
#' @rdname LazyAnd
#' @export
LazyOr <- function(a, b, fun, ...) {
  stopifnot(length(a)==1 || length(a)==length(b))
  a[is.na(a)|!a] <- a[is.na(a)|!a] & fun(b[is.na(a)|!a], ...)
  return(a)
}
# Lazyifelse(test, yFun, yIn, nFun, nIn): Lazy version of ifelse ----
#' Lazy version of ifelse
#'
#' When using ifelse, the return values are evaluated for all values, then discarded.
#' This causes problems when you want to check for valid inputs in test.
#' In this function, values are only evaluated when necessary:
#' yFun is called with yIn for test==TRUE, and
#' nFun is called with nIn for test==FALSE.
#' Missing (NA) values in test return NA, without calling either yFun or nFun
#' @param test an object which can be coerced to logical
#' @param yFun,nFun Functions to be called when test evaluates to TRUE or FALSE respectively
#' @param yIn,nIn Arguments for yFun and nFun. Recycled if necessary
#' @details If you just want to return values, you can use the function \code{\link[base]{identity}}
#' @examples
#' stats <- list(a=NA,
#'               b=list(time="1:00", speed=100))
#' besttimes <- Lazyifelse(is.na(stats), identity, NA, function(x) {sapply(x, `[[`, i='time')}, stats)
#' @export

Lazyifelse <- function(test, yFun, yIn, nFun, nIn) {
  out <- rep(NA, times=length(test))
  if(length(test) %% length(yIn)!=0) warning('yIn recycled partially (test not a multiple of yIn')
  if(length(test) %% length(nIn)!=0) warning('nIn recycled partially (test not a multiple of nIn')
  yIn <- rep(yIn, length.out=length(test))
  nIn <- rep(nIn, length.out=length(test))
  out[!is.na(test) & test] <- yFun(yIn[!is.na(test) & test])
  out[!is.na(test) & !test] <- nFun(nIn[!is.na(test) & !test])
  return(out)
}

# checkMasking(...): Check for possible masking problems in saved .R-files ----
#' Check for possible masking problems in saved .R-files
#'
#' When loading libraries, the function library warns if functions are masked, but it's often not clear if these functions are used in a script.\cr
#' This function reads the files named in "scripts" as texfiles, and scans for function-names that have possibly been masked, and returns a list of potential problems, along with line numbers./cr
#' Call this script after all relevant libraries have been loaded.\cr
#' It's not perfect, as the pattern matching to decide what is potentially a function-call and what is not is problematic\cr
#' Excluded are:\cr
#' \itemize{
#' \item Content after a "#"
#' \item Content between single or double quotes
#' \item Argument names in function calls: \code{fun(n=3, o=4)} will not warn for 'n' or 'o'
#' \item Field names: Identifiers preceded by "$"
#' \item Functions that have been explicitly assigned from a package at some place in the script: count <- plyr::count causes all mentions of count to be ignored.\cr
#'     Note that it's not checked WHERE this assignment takes place, nor if it takes place at all (e.g. in a conditional statement)
#' \item Functions of class 'standardGeneric', as they are meant to be overwritten.\cr
#'     Note the script still has some difficulties with this, as multiple methods in multiple packages may be defined, only seeming to mask each other
#'}
#' Furthermore, you can specify names that can be ignored (e.g. the name 'n' from dplyr::n gives lots of false positives if you assign n in .GlobalEnv)\cr
#' See also 'allowed' in the arguments
#' Checking only takes place for \emph{functions}, not for data-objects
#'
#' @param scripts A character vector with filenames to check
#' @param allowed A data.frame with often used functions, along with the package you intend to use with that, or "any".\cr
#'     Names in this data.frame are ignored in any scripts. Instead, if an environment is specified, the functions checks whether these names are not masked from the given environment.\cr
#'     For examples, you can look at getOption('checkMasking_Allowed'), the default value. If this option is unset when loading this library, it is set to some standard value, you can use these values as example.
#' @param extrascripts Another character vector with filenames, appended to scripts. The reason there are 2 is in order to specify your own script, to go along with standardscripts.\cr
#'     The value 'self' is treated differently: it tells the script to extract its own source code. This may fail if it is not available, in this case try \code{install.packages(..., type='source')} or \code{options(keep.source=TRUE)}
#' @param functions list of functions or function names for which source code should be checked.
#' @param packages list of packages for which all functions should be checked
#' @return 0 (invisibly) if no potentional problems have been found, otherwise a nested list with information.\cr
#'     The exact structure of the return may be changed in future versions, so is not meant to be automatically processed,\cr
#'     except for the check for a return of 0 for "no problems"\cr
#'     Right now, the structure is a list with elements for each script that has been processed (empty if no problems were found in that particular script, but if there were problems in other scripts)\cr
#'     These elements are list, with elements for each line with a problem, being character vectors with a line number, the contents of that line, and the name that triggered it's potential problem.\cr
#'
#' @details
#' This function makes use of the global options "checkMasking_Allowed" and checkMasking_extraScripts:\cr
#' See for information regarding checkMasking_Allowed at the "allowed" parameter.\cr
#'     If this library is loaded, and this option is unset, it is set to a default value.\cr
#'     If you don't want any values to be allowed, use options(checkMasking_Allowed='')\cr
#' The option checkMasking_extraScripts is useful if you have some code that is used over and over.\cr
#' If you want to check function from all loaded libraries, you can use\cr
#' \code{checkMasking(packages=search())}#'
#'
#' This function may fail to notice problems if it doens't recognize function-names well. Some pitfalls are:
#' \itemize{
#' \item Identifiers with non-standard characters, as the function splits up lines in 'words' by word-boundaries as used by the regular expression ('\\b')
#' \item Escaped characters may confuse the regexes.\cr
#'         E.g: paste('I wouldn\'t have thought this would cause',duplicateFunction(),'problems, I really didn\'t!') will not trigger an alert, because eveything between paired single quotes is ignored, even though some are escaped.\cr
#'         In this case, the script drops 'I wouldn' and ',duplicateFunction(),' and 't!'.\cr
#'         Or #'s as part of a string, as everything after # is ignored: gsub('#','',duplicateFunction(text)) passes.\cr
#' \item Libraries that have not yet been loaded are not checked! Advise is to specify all needed libraries first, then run 'checkMasking'.
#' \item Functions having their own environments may end up calling other functions then those first in the search path. This may cause both false positives and false negatives
#' \item If a function is marked \code{\link[base]{.Deprecated}} or \code{\link[base]{.Defunct}}, an attempt is made to let it pass. \cr
#'         The script looks for the "new" argument in .Deprecated or .Defunct. If there is none, no package is provided, or there is
#'         a replacement with a different name, the script lets it pass. If a package is provided, the script checks whether this package
#'         is higher on the search-list. \cr
#'         And the script of course only allows these functions to \emph{be} masked, not to mask others.
#'}
#' @export

checkMasking <- function(scripts=c(), allowed=getOption('checkMasking_Allowed'), extrascripts=c(getOption('checkMasking_extraScripts')), functions=c(), packages=c('own')) {
  if(is.null(allowed) || is.na(allowed) || allowed=='') allowed <- data.frame()
  allls <- sapply(search(), function(x) {as.character(utils::lsf.str(pos=x))})
  allls <- data.frame(name=unlist(allls, use.names = FALSE),
                      env=as.factor(unlist(sapply(names(allls), function(x) {rep(x, times=length(allls[[x]]))}))),
                      stringsAsFactors = FALSE, row.names = c())
  dupl <- allls[duplicated(allls$name) | duplicated(allls$name, fromLast = TRUE),]
  dupl <- dupl[!apply(dupl, 1, function(x) {class(get(x['name'], pos=x['env']))}) %in% c('standardGeneric'),]
  dupl <- dupl[!apply(dupl, 1, function(du) {
    ga <- utils::getAnywhere(du['name'])
    return(ga$dups[ga$where==du['env']])
  }),] # Identical according to getAnywhere
  dupl <- dupl[!apply(dupl, 1, function(x) {
    if(x[['name']]=='future_lapply') browser()
    if(x[['name']]=='checkMasking') return(TRUE)
    src <- utils::capture.output(get(x['name'], pos=x['env']))
    defp <- src[grepl('^ *(\\.Defunct)|(\\.Deprecated)', src)]
    if(!length(defp)) return(FALSE)
    defp <- defp[[1]]
    prs <- parse(text=defp)
    if(is.null(names(prs[[1]]))) {
      newfun <- prs[[1]][[2]]
    } else {
      newfun <- prs[[1]][-1][names(prs[[1]][-1])=='new'][[1]]
      if(is.null(newfun)) newfun <- prs[[1]][-1][names(prs[[1]][-1])==''][[1]]
    }
    if(!is.null(newfun) && !is.character(newfun) || length(newfun)>1) stop('A function calls .Defunct or .Deprecated, without clear arguments')
    if(!is.null(newfun)) newfun <- strsplit(newfun, split='::')[[1]]
    if(length(newfun)<2 || newfun[[2]]!=x[['name']]) {
      return(paste0(x, collapse='') %in% do.call(paste0, dupl[duplicated(dupl$name),]))
    } else {
      return(paste0('package:',newfun[[1]]) %in% search()[1:which(search()==x[['env']])])
    }
  }),] # Filter .Defunct and .Deprecated
  allowed <- allowed$name[allowed$env=='any' | apply(allowed, 1, function(x) {
    any(dupl$name[!duplicated(dupl$name)]==x['name'] & dupl$env[!duplicated(dupl$name)]==x['env'])
  })]
  dupl <- dupl[!dupl$name %in% allowed,]
  dupl <- dupl[duplicated(dupl$name) | duplicated(dupl$name, fromLast = TRUE),]
  if(nrow(dupl)==0) return(invisible(0))
  dupl$env <- sub('package:','',fixed=TRUE, dupl$env)
  packages <- lapply(packages, function(p) {
    if(p=='own') {
      environment()
    } else if(p %in% search()) {
      p
    } else if(paste0('package:',p) %in% search()) {
      paste0('package:',p)
    } else {
      warning('Package ',p,' not found, continuing with other code')
      return(NULL)
    }
  })
  tocheck <- list(stats::setNames(scripts,if(length(scripts)) paste0('scripts:',scripts)),
                  stats::setNames(extrascripts,if(length(extrascripts)) paste0('extrascripts:',extrascripts)),
                  stats::setNames(lapply(functions[sapply(functions, mode)!='function'], get, mode = 'function'),
                           if(any(sapply(functions, mode)!='function'))
                             paste0('functionnames:', functions[sapply(functions, mode)!='function'])),
                  stats::setNames(list(functions[sapply(functions, mode)=='function']),
                           if(any(sapply(functions, mode)=='function'))
                             paste0('directfunction nr ',1:sum(sapply(functions, mode)=='function')) else NULL),
                  rapply(packages, how='unlist', function(p) {lapply(as.character(utils::lsf.str(p)), function(f) {
                    stats::setNames(list(get(f, pos=p)),paste0(p,':',f))})}))
  tocheck <- unlist(tocheck)
  mentions <- lapply(tocheck, function(f) {
    if(mode(f)!='function' && (is.null(f) || is.na(f) || length(f)==0 || f=='')) return(list())
    if(mode(f)=='function') {
      lines <- utils::capture.output(f)
      if(!is.null(environment(f)))
        allowed <- c(allowed, as.character(utils::lsf.str(environment(f))))
    } else if(f=='self') {
      lines <- utils::capture.output(checkMasking)
      allowed <- c(allowed, as.character(utils::lsf.str(environment(checkMasking))), as.character(utils::lsf.str(environment())))
    } else {
      lines <- readLines(f)
    }
    names(lines) <- 1:length(lines)
    # Explanation of gsub:
    # Everything after # is ignored (comments): '(#.*$)'
    # Content between single or double quotes is ignored: '(\'.*?\')' and '(".*?")'
    # Names of arguments passed to functions are ignored, that is, anything of the form "(name=" for first arguments, or ", name=" for seconds:
    # "(((, ?)|\\()[a-z]+=[^=])"
    # Field names, everything directly after a $ sign: '(\\$[A-Za-z0-9_\\.]+)'
    lines <- gsub('(#.*$)|(\'.*?\')|(".*?")|(((, ?)|\\()[a-z]+=[^=])|(\\$[A-Za-z0-9_\\.]+)','', lines)
    lines <- lines[lines!='']
    # Add to the list of allowed names, anything that is declared somewhere.
    # So if somewhere in a script there is a line containing 'count <- plyr::count', then 'count' is allowed
    # Note that this assignment has local scope, so this is only valid for the script being evaluated
    allowed <- unique(c(allowed, dupl$name[sapply(dupl$name, function(x) {
      isTRUE(grep(x, lines)[1]==grep(paste0(x,' ?<- ?[a-zA-Z]+::',x), lines)[1])
    })]))
    if(all(dupl$name %in% allowed)) return()
    # And now we can remove any mentions of duplicate functions that are explicitly called
    lines <- gsub('[a-z]+::`?[a-z]+`?','', lines)
    # We use 2 ways of searching: as a regular expression with word-boundaries for 'normal' function names, and simpler approach for "complicated" functionnames
    # So looking for \\bduplicateFunction\\b, this is stored in regexes
    # Not in one step because paste ('',character(0))  is recyclecasted to paste0('','')
    regexes <- dupl$name[grepl('^[a-z]*$', dupl$name)&!dupl$name %in% allowed]
    if(length(regexes)) regexes <- unique(paste0('\\b',regexes,'\\b'))
    # And second, a list of not-so-regular-expressions, e.g. looking for masking of '+' or `<-`. Not clear where word-boundaries are, so just using fixed grep
    fixed <- unique(dupl$name[!grepl('^[a-z]*$', dupl$name)&!dupl$name %in% allowed])
    lines <- lines[sapply(lines, function(l) {any(sapply(regexes, grepl, x=l),
                                                  sapply(fixed, grepl, x=l, fixed=TRUE))})]
    if(length(lines)>0) {
      # Find out which regex triggered a TRUE return for each line.
      # Note that if multiple functions/regexes on one line triggered a return, only the first one is considered
      if(length(regexes)) {
        fault <- gsub('^\\\\b|\\\\b$','',
                      regexes[sapply(lines, function(l) {which(sapply(regexes, grepl, x=l))[1]})])
      } else {
        fault <- rep(NA,length(lines))
      }
      # If return is NA, this means the return was triggered by one of the fixed, not-so-regular-expressions
      if(any(is.na(fault))) {
        fault[is.na(fault)] <- gsub('^\\\\b|\\\\b$','',
                                    fixed[sapply(lines[is.na(fault)], function(l) {which(sapply(fixed, grepl, x=l, fixed=TRUE))[1]})])
      }
      return(data.frame(linenumber=names(lines), line=lines, maskedName=fault))
    } else {
      return()
    }
  })
  if(!all(sapply(mentions, length)==0)) {
    return(mentions[sapply(mentions, length)>0])
  } else {
    return(invisible(0))
  }
}

# out(...): printing and simultaneously writing to a logfile ----
#' Customary function for printing output and simultaneously writing to a logfile
#'
#' Character vectors are printed using cat instead of print.\cr
#' Multiple arguments are accepted, as seperate calls\cr
#' Any output is first evaluated (in its entirety), then printed to files, finally to console
#'
#' @param ... Objects to print/write to file
#' @param logpath Filename(s) of file(s) to print to, beside console. NULL if you just want to print to console.
#'
#' @export

out <- function(..., logpath=getOption('StandardPaths')[['TextOutput']]) {
  args <- list(...)
  while(length(args)>0) {
    chunk <- args[[1]]
    args <- args[-1]
    while(length(args)>0 && class(args[[1]])==class(chunk[[1]]) && class(chunk[[1]])=='character') {
      chunk <- c(chunk, args[[1]])
      args <- args[-1]
    }
    .out(chunk, logpath)
  }

}
.out <- function(text, filepath) {
  tempwidth <- getOption('width')
  for(filename in filepath) {
    sink(filename, append=TRUE)
    options(width=200)
    if(class(text)=='character') {
      cat(text,'\n')
    } else {
      print(text)
    }
    sink()
  }
  options(width=tempwidth)
  if(class(text)=='character') {
    cat(text,'\n')
  } else {
    print(text)
  }
}

# parent.nenv(env, n): Get parent, grandparent, grandgrandparent, etc. ----
#' Access environments further in the definition chain
#'
#' Get the parent, grandparent, grandgrandparent of an environment
#' @param env an environment
#' @param n how many steps to go up the chain, >= 0
#'
#' @return An enclosing environment
#'
#' @examples
#' myfun <- function(x) {
#'   myfun2 <- function(x2) {
#'     x+x2
#'   }
#'   x <- x+1
#'   return(myfun2)
#' }
#' parent.env(environment(myfun(1))) # That is myfuns environment
#' parent.env(parent.env(environment(myfun(1))))
#'   # This is the environment in which myfun was defined, normally .GlobalEnv
#' parent.nenv(environment(myfun(1)), 2) # The same call, but clearer
#'
#' @export
parent.nenv <- function(env, n) {
  stopifnot(is.environment(env), is.numeric(n), n>=0)
  if(n==0) {
    return(env)
  } else {
    return(parent.env(parent.nenv(env, n-1)))
  }
}
# More functions ----
















