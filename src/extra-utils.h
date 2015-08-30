#ifndef FST_EXTRA_UTILS_H__
#define FST_EXTRA_UTILS_H__

#include <fst/compat.h>
#include <fst/types.h>
#include <algorithm>
#include <iostream>
#include <fstream>
#include <string>
#include <math.h>

	//************************
	//USEFUL UTILITY FUNCTIONS
	//************************
	
	// trim from start
	 static inline std::string &ltrim(std::string &s) {
	   s.erase(s.begin(), std::find_if(s.begin(), s.end(), std::not1(std::ptr_fun<int, int>(std::isspace))));
	   return s;
	 }

	 // trim from end
	 static inline std::string &rtrim(std::string &s) {
	   s.erase(std::find_if(s.rbegin(), s.rend(), std::not1(std::ptr_fun<int, int>(std::isspace))).base(), s.end());
	   return s;
	 }

	 // trim from both ends
	 static inline std::string &trim(std::string &s) {
	   s.erase(std::remove(s.begin(), s.end(), '\n'), s.end());
	   return ltrim(rtrim(s));
	 }

	 static inline std::vector<std::string> &split(const std::string &s, char delim, std::vector<std::string> &elems) {
	   std::stringstream ss(s);
	   std::string item;
	   if(s.empty())
	     return elems;
	   while(std::getline(ss, item, delim)) {
	     elems.push_back(item);
	   }
	   return elems;
	 }

	 static inline std::vector<std::string> &split(const std::string &s, char delim, std::vector<std::string> &elems, int num_of_splits) {
	   std::stringstream ss(s);
	   std::string item;
	   if(s.empty())
	     return elems;
	   int num_of_elems;
	   while(std::getline(ss, item, delim)) {
             num_of_elems++;
	     elems.push_back(item);
             if(num_of_elems == num_of_splits)
	       break;
	   }
	   return elems;
	 }

	 // split using a delimiter
	 static inline std::vector<std::string> split(const std::string &s, char delim) {
	   std::vector<std::string> elems;
	   return split(s, delim, elems);
	 }

	 //split into specified number of splits using a delimiter
	 static inline std::vector<std::string> split(const std::string &s, char delim, int num_of_splits) {
	   std::vector<std::string> elems;
	   return split(s, delim, elems, num_of_splits);
	 }

#endif // FST_EXTRA_UTILS_H__
