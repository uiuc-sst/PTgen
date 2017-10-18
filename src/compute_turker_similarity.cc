#include <iostream>
#include <sstream>
#include <functional>
#include <string>
#include <vector>
#include <cstdlib>
#include <tr1/unordered_map>
#include "extra-utils.h"

const auto MAXTURKERS = 12;

using namespace std;

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

// Calculate the edit distance between two word sequences.
// (dynamic programming, e.g. Jurafsky & Martin (2000) p. 156, fig 5.5).
double editdistance(const string& str1, const string& str2) {
	vector<string> words1, words2;
	vectorOfWords(words1, str1);
	vectorOfWords(words2, str2);

	// Substitution and Insertion/Deletion costs.
	constexpr auto scost = 1.0, idcost = 1.0;

	const auto len1 = words1.size();
	const auto len2 = words2.size();
	if (len1 == 0)
		return idcost*len2;	// insert len2 times into an empty sequence
	if (len2 == 0)
		return idcost*len1;	// insert len1 times into an empty sequence

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
			dist_matrix[i][j] = std::min({
			    dist_matrix[i-1][j  ] + idcost,	// insert
			    dist_matrix[i  ][j-1] + idcost,	// delete
			    dist_matrix[i-1][j-1] + cost });	// substitute
		}
	}
	const auto edist = dist_matrix[len1][len2];
	for (auto i = 0u; i <= len1; ++i)
		delete[] dist_matrix[i];
	delete[] dist_matrix;
	return edist - len1 - len2;
}

int main(int argc, char** argv) {
	// On standard input, expects a bunch of Turker transcriptions.
	// On standard output, prints the transcriptions' similarity scores.
	// Ignores command-line arguments.

	double turk_matrix[MAXTURKERS][MAXTURKERS];
	vector<pair<double,int> > scores;
	string line;
	while (getline(cin, line)) {
		if (line.empty())
			continue;
		vector<string> entries = split(line, ':');
		cout << trim(entries[0]); // uttid
		const vector<string> transcripts = split(entries[1], '#');
		const auto numTranscripts = transcripts.size();
		if (numTranscripts <= 0) {
		  cerr << "\ncompute_turker_similarity: no #-delimited transcripts in '" << line << "'.  Aborting.\n";
		  return 1;
		}
		if (numTranscripts > MAXTURKERS) {
		  cerr << "\ncompute_turker_similarity: too many #-delimited transcripts in\n'"
		       << line << "'.  Recompile compute_turker_similarity.cc with MAXTURKERS >= " << numTranscripts << ".  Aborting.\n";
		  return 1;
		}
		if (numTranscripts == 1) {
#if 0
		    // Clone the single transcript so everything downstream works,
		    // albeit slower than with a single transcript instead of two.
		    // This emits "IL5_EVAL_037_009_034761998_036003497,1:1,2:1";
		    // mergedir/IL5_EVAL_072_008_042195975_043437033.txt then gets
		    // two identical columns of phone-indices.
		    // This hack validates the non-hack in the #else.
		    transcripts.push_back(transcripts[0]); // Clone.
		    numTranscripts = 2; // Not const.
#else
		    // First 1: the (unique) turker index.
		    // Second 1: the turker's score, because simscore becomes 1 below
		    // when there's only one score because bestscore==worstscore.
		    cout << ",1:1\n";
		    continue;
#endif
		}
		scores.resize(numTranscripts);
		for (auto i = 0u; i < numTranscripts; ++i) {
			// Store a large score in the i'th turker's entry.
			for (auto k = i+1; k < numTranscripts; ++k) {
				turk_matrix[k][i] =
				turk_matrix[i][k] =
					editdistance(transcripts[i], transcripts[k]);
			}
		}
		for (auto i = 0u; i < numTranscripts; ++i) {
			scores[i] = {0.0, i};
			for (auto j = 0u; j < numTranscripts; ++j) {
				if (i != j)
					scores[i].first += turk_matrix[i][j];
			}
		}
		std::sort(scores.begin(), scores.end());
		const auto worstscore = scores[scores.size()-1].first;
		const auto bestscore =  scores[0              ].first;
		assert(bestscore < 0.0);

		// Print each turker's index (starting at 1) and score.
		auto simscore = 1.0;
		for (const auto& score: scores) {
			if (bestscore != worstscore) // Avoid DBZ.
				simscore = (score.first - worstscore) / (bestscore - worstscore);
			cout << "," << score.second + 1 << ":" << simscore;
		}
		cout << endl;
	}
	return 0;
}
