
#' Create a parser skeleton
#' @param type The type of parser (`"cpopg"` or `"cposg"`)
#' @export
make_parser <- function(type = "cposg") {
  list(name = NULL, getter = NULL) %>% rlang::set_attrs("class" = c("parser", type))
}

#' Run a parser
#' @param file A character vector with the paths to one ore more files
#' @param parser A parser returned by [make_parser()]
#' @param path The path to a directory where to save RDSs
#' @param cores The number of cores to be used when parsing
#' @export
run_parser <- function(file, parser, path = ".", cores = 1) {

  # Check if parser is a parser
  stopifnot("parser" %in% class(parser))

  # Given a parser and a file, apply getters
  apply_getters <- function(file, parser_path) {

    # Resolve parallelism problem
    parser <- parser_path$parser
    path <- parser_path$path

    # Apply all getters
    html <- xml2::read_html(file)

    if (hidden_lawsuit(html)) {
      empty_cols <- parser_path$parser$name %>%
        purrr::map(~list(tibble::tibble())) %>%
        purrr::set_names(parser_path$parser$name) %>%
        tibble::as_tibble()
      out <- tibble::tibble(
        id = stringr::str_extract(tools::file_path_sans_ext(basename(file)), "(?<=_).+"),
        file, hidden = TRUE) %>%
        dplyr::bind_cols(empty_cols)
    } else {
      out <- parser$getter %>%
        purrr::invoke_map(list(list("html" = html))) %>%
        purrr::set_names(parser$name) %>%
        purrr::modify(list) %>%
        dplyr::as_tibble() %>%
        dplyr::mutate(
          file = file,
          id = stringr::str_extract(tools::file_path_sans_ext(basename(file)), "(?<=_).+"),
          hidden = FALSE) %>%
        dplyr::select(id, file, hidden, dplyr::everything())
    }

    # Write and return
    readr::write_rds(out, stringr::str_c(path, "/", out$id, ".rds"))
    return(out)
  }

  # Create path if necessary
  dir.create(path, showWarnings = FALSE, recursive = TRUE)

  # Apply getters to all files
  parser_path <- list(parser = parser, path = path)
  parallel::mcmapply(
    apply_getters, file, list(parser_path = parser_path),
    SIMPLIFY = FALSE, mc.cores = cores) %>%
    dplyr::bind_rows()
}

# Check if lawsuit has secret of justice
hidden_lawsuit <- function(html) {
  !is.na(rvest::html_node(html, "#popupSenhaProcesso"))
}

#' Shortcut for creating and running a complete CPOSG parser
#' @param file A character vector with the paths to one ore more files
#' @param path The path to a directory where to save RDSs
#' @param cores The number of cores to be used when parsing
#' @export
parse_cposg_all <- function(file, path = ".", cores = 1) {
  parser <- parse_decisions(parse_parts(parse_data(parse_movs(make_parser()))))
  run_parser(file, parser, path, cores)
}

#' Shortcut for creating and running a complete CPOPG parser
#' @param file A character vector with the paths to one ore more files
#' @param path The path to a directory where to save RDSs
#' @param cores The number of cores to be used when parsing
#' @export
parse_cpopg_all <- function(file, path = ".", cores = 1) {
  parser <- parse_pd(parse_hist(parse_hearings(parse_parts(parse_data(parse_movs(make_parser("cpopg")))))))
  run_parser(file, parser, path, cores)
}
