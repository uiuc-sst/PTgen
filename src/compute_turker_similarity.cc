#include <iostream>
#include <sstream>
#include <functional>
#include <string>
#include <vector>
#include <cstdlib>
#include <tr1/unordered_map>
#include "extra-utils.h"

const auto MAXTURKERS = 15;

using namespace std;
using namespace std::tr1;

void vectorOfWords(vector<string>& words, const string& str) {
	stringstream ss(str);
	string item;
	while (getline(ss, item, ' ')) {
		string result;
		std::remove_copy_if(item.begin(), item.end(),            
			std::back_inserter(result), // store output without punctuations
			std::ptr_fun<int, int>(&std::ispunct));
		words.push_back(result);
	}
}

// Compute the edit distance between two word sequences (dynamic programming).
double editdistance(const string& str1, const string& str2) {
	vector<string> words1, words2;
	vectorOfWords(words1, str1);
	vectorOfWords(words2, str2);

	// Substitution and Insertion/Deletion costs.
	constexpr auto scost = 1.0, idcost = 1.0;

	const auto len1 = words1.size();
	const auto len2 = words2.size();
	if (len1 == 0)
		return idcost*len2;
	if (len2 == 0)
		return idcost*len1;

	// A 1-dimensional len1 * len2 matrix might be faster,
	// but already, this exe takes only a few seconds, a tiny fraction of run.sh.
	auto dist_matrix = new double* [len1+1];
	for (auto i = 0u; i <= len1; ++i) {
		dist_matrix[i] = new double[len2+1];
		for (auto j = 0u; j <= len2; ++j) {
			dist_matrix[i][j] = 0.0;
			dist_matrix[0][j] = j*idcost;
		}
		dist_matrix[i][0] = i*idcost;
	}

	for (auto i = 1u; i <= len1; ++i) {
		for (auto j = 1u; j <= len2; ++j) {
			const auto cost = words1[i-1] == words2[j-1] ? 0.0 : scost;
			const auto mn = std::min(dist_matrix[i-1][j], dist_matrix[i][j-1]) + idcost;
			dist_matrix[i][j] = std::min(mn, dist_matrix[i-1][j-1]+cost);
		}
	}
	const auto edist = dist_matrix[len1][len2];
	for (auto i = 0u; i <= len1; ++i)
		delete[] dist_matrix[i];
	delete[] dist_matrix;
	return edist - len1 - len2;
}

int main(int argc, char** argv) {
	if (argc != 2) {
		cerr << "Usage: " << argv[0] << " <file with Turker transcriptions>\n";
		return 1;
	}

	ifstream ifile;
	ifile.open(argv[1]);
	if (!ifile) {
		cerr << argv[0] << ": failed to open ifile" << argv[1] << "\n";
		return 1;
	}

	double turk_matrix[MAXTURKERS][MAXTURKERS];
	vector<pair<double,int> > turkscores;
	while (!ifile.eof()) {
		string line;
		getline(ifile, line);
		if (!line.empty()) {
			vector<string> entries = split(line, ':');
			cout << trim(entries[0]); // uttid
			const vector<string> turktranscripts = split(entries[1], '#');
			assert(turktranscripts.size() <= MAXTURKERS);
			assert(turktranscripts.size() > 1);
				// Otherwise turkscores = (0.0, 0), and then
				// assert(bestscore < 0.0) fails.
			turkscores.resize(turktranscripts.size());
			for (auto i = 0u; i < turktranscripts.size(); ++i) {
				// Store a large score in the entry corresponding to Turker i
				for (auto k = i+1; k < turktranscripts.size(); ++k) {
					turk_matrix[k][i] =
					turk_matrix[i][k] =
						editdistance(turktranscripts[i], turktranscripts[k]);
				}
			}
			for (auto i = 0u; i < turktranscripts.size(); ++i) {
				turkscores[i] = {0.0, i};
				for (auto j = 0u; j < turktranscripts.size(); ++j) {
					if (i != j)
						turkscores[i].first += turk_matrix[i][j];
				}
			}
			std::sort(turkscores.begin(), turkscores.end());
			const auto worstscore = turkscores[turkscores.size()-1].first;
			const auto bestscore =  turkscores[0                  ].first;
			assert(bestscore < 0.0);

			// Print 1-indexed turker indices.
            		auto simscore = 1.0;
			for (const auto& score: turkscores) {
                		if (bestscore != worstscore) // Avoid DBZ.
					simscore = (score.first - worstscore) / (bestscore - worstscore);
				cout << "," << score.second + 1 << ":" << simscore;
			}
			cout << endl;
		}
	}
	ifile.close();
	return 0;
}
