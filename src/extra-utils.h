// Utility functions.

#ifndef FST_EXTRA_UTILS_H__
#define FST_EXTRA_UTILS_H__

// Although this file doesn't need OpenFST itself, its callers typically do.
#include <fst/compat.h>
#include <fst/types.h>

#include <algorithm>
#include <cmath>
#include <fstream>
#include <iostream>
#include <string>

// (In .h files, "using std::string" etc is unsafe.)

// Trim leading whitespace.
static inline std::string &ltrim(std::string &s) {
  s.erase(s.begin(), std::find_if(s.begin(), s.end(), std::not1(std::ptr_fun<int, int>(std::isspace))));
  return s;
}

// Trim trailing whitespace.
static inline std::string &rtrim(std::string &s) {
  s.erase(std::find_if(s.rbegin(), s.rend(), std::not1(std::ptr_fun<int, int>(std::isspace))).base(), s.end());
  return s;
}

// Trim whitespace from both ends.
static inline std::string& trim(std::string &s) {
  s.erase(std::remove(s.begin(), s.end(), '\n'), s.end());
  return ltrim(rtrim(s));
}

static inline std::vector<std::string> &split(const std::string &s, const char delim, std::vector<std::string> &elems) {
  if (s.empty())
    return elems;
  std::stringstream ss(s);
  std::string item;
  while (std::getline(ss, item, delim))
    elems.push_back(item);
  return elems;
}

static inline std::vector<std::string> &split(const std::string &s, const char delim, std::vector<std::string> &elems, const int num_splits) {
  if (s.empty())
    return elems;
  std::stringstream ss(s);
  std::string item;
  for (int num_elems = 0; num_elems < num_splits && std::getline(ss, item, delim); ++num_elems)
    elems.push_back(item);
  return elems;
}

// Split using a delimiter.
static inline std::vector<std::string> split(const std::string &s, const char delim) {
  std::vector<std::string> elems;
  return split(s, delim, elems);
}

// Split using a delimiter, into at most n parts.
static inline std::vector<std::string> split(const std::string &s, const char delim, const int num_splits) {
  std::vector<std::string> elems;
  return split(s, delim, elems, num_splits);
}

#endif // FST_EXTRA_UTILS_H__
