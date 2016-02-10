#include <bitset>
#include <cfloat>
#include <cstdlib> // atof
#include <iostream>
#include <map>
#include <string>
#include <vector>

#include "extra-utils.h"

using std::bitset;
using std::ifstream;
using std::map;
using std::pair;
using std::string;
using std::vector;

const int MAXSTRINGS = 6;
typedef float cost_t;
typedef string tok_t;
typedef map<pair<tok_t,tok_t>, cost_t> dmap_t;

const tok_t default_emptytok = "_";
const tok_t dummytoken = "__DUMMY__";
const cost_t default_dist = 1;

/* Input format: rows of space-separated tokens
 * Output format: columns of tab-separated tokens; may contain emptytok symbols
 */

struct elem_t {
    int revptr;           // from compressindex()
    unsigned short width; // length of chain of reverse pointers
    cost_t cost;
};

// Multidimensional array of E's (in this program, of strings).
template <class E>
class Table
{
    vector<unsigned> dim;
    vector<E> tab;

public:
    Table(const vector<unsigned>& dimensions) {
	dim = dimensions; // Keep a local copy.
	int size = 1;
	for (unsigned i=0; i < dimensions.size(); ++i)
	    size *= dimensions[i];
	tab.resize(size);
    }

    unsigned size() const {
	 return tab.size();
    }

    unsigned compressindex(const vector<unsigned>& vindex) const {
	unsigned ind = vindex[0];
	for (unsigned i=1; i < dim.size(); ++i) {
	    assert(vindex[i] < dim[i]);
	    ind *= dim[i];
	    ind += vindex[i];
	}
	return ind;
    }

    void expandindex(unsigned ind, vector<unsigned>& vindex) const {
	vindex.clear();
	vindex.resize(dim.size());
	for (unsigned i=dim.size()-1; i > 0; --i) {
	    vindex[i] = ind % dim[i];
	    ind /= dim[i];
	}
	vindex[0] = ind;
    }

    // Offset corresponds to a binary vector.
    // If can't subtract, returns -1.
    int subtractindex(const unsigned ind, const unsigned offset) {
	assert(offset < pow(2,dim.size()));
	vector<unsigned> vindex;
	vector<unsigned> twos(dim.size(),2);
	expandindex(ind,vindex);
	const bitset<MAXSTRINGS> bindex(offset);
	for (unsigned i=0; i<dim.size(); ++i) {
	    if (vindex[i]==0 && bindex[i]==1)
		return -1;
	    vindex[i] -= bindex[i];
	}
	return compressindex(vindex);
    }

    E& at(const unsigned i) { return tab[i]; }
    E& at(const vector<unsigned>& i) { return at(compressindex(i)); }
    E& operator[](int i) { return tab[i]; }
    E& operator[](const vector<unsigned>& i) { return at(compressindex(i)); }
};

dmap_t* makedmap(string dfile)
{
    ifstream din(dfile.c_str());
    if (!din.is_open()) {
        cerr << "Warning: Could not open file '" << dfile << "'. Using defaults instead.\n";
        return NULL;
    }
    dmap_t* dmap = new dmap_t;
	string line;
	while (getline(din, line)) {
	    if (!line.empty()) {
		vector<tok_t> tokens = split(line, ' ');
            assert(tokens.size() == 3);
            (*dmap)[make_pair(tokens[0],tokens[1])] = atof(tokens[2].c_str());
        }
    }
    return dmap;
}

cost_t dist(tok_t& t1, tok_t& t2, dmap_t* dmap, cost_t dfltdist)
{
    const pair<tok_t,tok_t> key = make_pair(t1,t2);
    if (dmap == NULL || dmap->count(key) == 0)
        return (t1 == t2) ? 0 : dfltdist;
    return (*dmap)[key];
}

cost_t distance(vector<tok_t>& tv, dmap_t* dmap = NULL, cost_t dfltdist = default_dist)
{
    cost_t cost = 0;
    for (unsigned i=0; i < tv.size(); ++i)
        for (unsigned j=i+1; j < tv.size(); ++j)
            cost += dist(tv[i],tv[j],dmap,dfltdist);
    return cost;
}

unsigned int align(const vector <vector <tok_t> >& input, const tok_t etok, dmap_t* dmap, vector<vector <tok_t> >& output)
{
    const unsigned n = input.size();
    vector<unsigned> dimensions(n);
    for (unsigned i=0; i < n; ++i)
        dimensions[i] = input[i].size();

    Table<elem_t> table(dimensions);
    table[0].revptr = 0; // Like a null pointer.
    table[0].width  = 0;
    table[0].cost   = 0;

    const unsigned nbhd = pow(2,n);
    const unsigned T = table.size();

    for (unsigned t=1; t < T; ++t) {
        elem_t e;
	e.cost = FLT_MAX; // Greater than any valid cost.
        vector <unsigned> vt;
        table.expandindex(t,vt);
        for (unsigned k = 1; k < nbhd; ++k) {
            const int nbr = table.subtractindex(t,k);
            if (nbr<0)
                continue;

            // Assemble the "current tokens vector", using lowest cost.

            vector<tok_t> toks;
            toks.reserve(n);
            const bitset<MAXSTRINGS> bk(k);
            for (unsigned j=0; j < n; ++j)
                toks[j] = bk[j] ? input[j][vt[j]] : etok;

            const cost_t newcost = distance(toks,dmap) + table[nbr].cost;
            if (newcost < e.cost) {
                e.cost = newcost;
                e.revptr = nbr;
                e.width = table[nbr].width + 1;
            }
        }
        table[t] = e;
    }

    // Assemble output, starting from table[T-1].
    unsigned w = table[T-1].width;
    output.clear();
    output.resize(n);
    for (unsigned i=0; i < n; ++i)
        output[i].resize(w);

    for (unsigned t = T-1; t > 0; t = table[t].revptr, --w) {
       assert(w>0);
       const unsigned r = table[t].revptr;
       vector<unsigned> vt, vr;
       table.expandindex(t,vt);
       table.expandindex(r,vr);
       for (unsigned i=0; i<n; ++i)
            output[i][w-1] = vt[i]==vr[i] ? etok : input[i][vt[i]];
    }
    return table[T-1].width;
}

int main(int argc, char** argv)
{
    string distfile;
    tok_t emptytok = default_emptytok;
    bool flip = true;

    // Parse command-line arguments.
    {
	string argerr;
	for (int a=1; a < argc; ++a) {
	    const string arg(argv[a]);
	    if (arg == "--noflip") {
		flip = false;
	    } else if (arg == "--dist") {
		 if (++a == argc)
		     argerr = "Missing distance file"; // Needn't break, because the loop ends anyways.
		 else
		     distfile = argv[a];
	    } else if (arg == "--empty") {
		if (++a == argc)
		    argerr = "Missing empty-token"; // Needn't break, because the loop ends anyways.
		else
		    emptytok = argv[a];
	    } else {
		argerr = "Unknown argument: " + arg;
		break; // Don't parse remaining args.
	    }
	}
	if (!argerr.empty()) {
	    cerr << "Error: " << argerr << "\nUsage: " << argv[0] << " [--empty empty_token] [--dist <distance file>]\n";
	    exit(1);
	}
    }

    dmap_t* dmap = distfile.empty() ? NULL : makedmap(distfile);

    // Parse the standard input.
    vector <vector <tok_t> > input;
    {
	string line;
	while (getline(cin, line) && input.size() < MAXSTRINGS) {
	    if (line.empty())
		continue;
	    line = dummytoken + " " + line;
	    const vector<tok_t> tokens = split(line, ' ');
	    input.push_back(tokens);
	}
    }

    // Output the 2D array, transposed iff "flip".
    vector <vector <tok_t> > output;
    const unsigned width = align(input,emptytok,dmap,output);
    if (flip) {
        for (unsigned j=0; j < width; ++j) {
            for (unsigned i=0; i < output.size(); ++i)
                cout << output[i][j] << " ";
            cout << "\n";
        }
    } else {
        for (unsigned i=0; i < output.size(); ++i) {
            for (unsigned j=0; j < width; ++j)
                cout << output[i][j] << " ";
            cout << "\n";
        }
    }
    return 0;
}
