#include <iostream>
#include <sstream>
#include <functional>
#include <string>
#include <vector>
#include <cstdlib>
#include <tr1/unordered_map>
#include "extra-utils.h"

const int MAXTURKERS = 15;

using namespace std;
using namespace std::tr1;

float editdistance(const char* a, const char* b) {
	string str1(a);
	string str2(b);
	
	/************************************
	 * Computing edit distance between two word sequences
	 ***********************************/
	vector<string> wrds1;
	vector<string> wrds2;
	stringstream ss1(str1);
	string item1,item2,result;
	// Substitution and Insertion/Deletion costs.
	float scost = 1.0, idcost = 1.0;
	while (getline(ss1, item1, ' ')) {
		std::remove_copy_if(item1.begin(), item1.end(),            
			std::back_inserter(result), //Store output without punctuations
			std::ptr_fun<int, int>(&std::ispunct));
		wrds1.push_back(result);
		result = "";
	}
	stringstream ss2(str2);
	while (getline(ss2, item2, ' ')) {
		std::remove_copy_if(item2.begin(), item2.end(),            
			std::back_inserter(result), //Store output without punctuations
			std::ptr_fun<int, int>(&std::ispunct));
		wrds2.push_back(result);
		result = "";
	}

	const int len1 = wrds1.size();
	const int len2 = wrds2.size();
	if(len1 == 0)
		return idcost*len2;
	if(len2 == 0)
		return idcost*len1;
	float** dist_matrix = new float* [len1+1];
	for(int i = 0; i <= len1; i++)
		dist_matrix[i] = new float[len2+1];
	for(int i = 0; i <= len1; i++) {
		for(int j = 0; j <= len2; j++) {
			dist_matrix[i][j] = 0.0;
			dist_matrix[0][j] = j*idcost;
		}
		dist_matrix[i][0] = i*idcost;
	}

	//Dynamic programming algorithm to compute edit distance between two word sequences
	for(int i = 1; i <= len1; i++) {
		for(int j = 1; j <= len2; j++) {
			const float cost = (wrds1[i-1] == wrds2[j-1]) ? 0 : scost;
			const float mn = std::min(dist_matrix[i-1][j]+idcost,dist_matrix[i][j-1]+idcost); 
			dist_matrix[i][j] = (mn < dist_matrix[i-1][j-1]+cost) ? mn : dist_matrix[i-1][j-1]+cost; 
		}
	}
	const float edist = dist_matrix[len1][len2];
	for(int i = 0; i <= len1; i++)
		delete[] dist_matrix[i];
	delete[] dist_matrix;

	return edist - len1 - len2;
}

// Convert the edit distance into a score that increases with better matches.
int convert2score(float dist) {
	return int(500.0 / (dist + 5.0));
}

int main(int argc, char** argv) {
	if(argc != 2) {
		cerr << "Usage: " << argv[0] << " <file with Turker transcriptions>\n";
		return 1;
	}

	ifstream ifile;
	ifile.open(argv[1]);
	if(!ifile) {
		cerr << "Could not open ifile" << argv[1] << "\n";
		return 1;
	}

	float** turk_matrix = new float* [MAXTURKERS];
	for(int i = 0; i < MAXTURKERS; i++)
		turk_matrix[i] = new float[MAXTURKERS];

	vector<pair<float,int> > turkscores; // why not double?
	while(!ifile.eof()) {
		string line;
		getline(ifile, line);
		if(!line.empty()) {
			vector<string> entries = split(line, ':');
			string uttid = trim(entries[0]);
			cout << uttid;
			vector<string> turktranscripts = split(entries[1], '#');
			turkscores.resize(turktranscripts.size());
			for(unsigned i = 0; i < turktranscripts.size(); i++) {
				// Store a large score in the entry corresponding to Turker i
				for(unsigned k = i+1; k < turktranscripts.size(); k++) {
					turk_matrix[i][k] = editdistance(turktranscripts[i].c_str(), turktranscripts[k].c_str());
					turk_matrix[k][i] = turk_matrix[i][k];
				}
			}
			for (unsigned i = 0; i < turktranscripts.size(); i++) {
				turkscores[i] = make_pair(0.0, i);
				for (unsigned j = 0; j < turktranscripts.size(); j++) {
					if (i != j)
						turkscores[i].first += turk_matrix[i][j];
				}
			}
			std::sort(turkscores.begin(), turkscores.end());

			const double worstscore = turkscores[turkscores.size()-1].first;
			const double bestscore = turkscores[0].first;
			assert(bestscore < 0.0);
            		float simscore = 1.0;
			for (size_t st = 0; st < turkscores.size(); ++st) {
                		if (bestscore != worstscore)
					simscore = (turkscores[st].first - worstscore)/(bestscore-worstscore); //print 1-indexed turker indices
				cout << "," << turkscores[st].second + 1 << ":" << simscore; //print 1-indexed turker indices
			}

			cout << endl;
		}
	}
	ifile.close();
}
