#include <iostream>
#include <cstdlib>     /* atof */
#include <string>
#include <vector>
#include <bitset> 
#include <map> 
#include "extra-utils.h"

using namespace std;

#define MAXSTRINGS 6
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
    int revptr; // obtained using compressindex
    unsigned short width; // #elements in the reverse pointer chain
    cost_t cost; 
};

template <class E> 
class Table
{
     public:
         Table(const vector<unsigned >& dimensions) {
              dim = dimensions;
              int size = 1;
              for (unsigned  i=0; i < dimensions.size(); i++) {
                   size *= dimensions[i];
              }
              tab.resize(size);
         }

         unsigned  size() {
              return tab.size();
         }

         unsigned  compressindex (const vector<unsigned >& vindex) {
             unsigned  ind = vindex[0];
             for (unsigned  i=1; i < dim.size(); i++) {
                 assert (vindex[i] < dim[i]);
                 ind *= dim[i];
                 ind += vindex[i];
             }
             return ind;
         }

         void expandindex (unsigned  ind, vector<unsigned >& vindex) {
             vindex.clear();
             vindex.resize(dim.size());
             for (unsigned  i=dim.size()-1; i > 0; i--) {
                 vindex[i] = ind % dim[i];
                 ind /= dim[i];
             }
             vindex[0] = ind;
         }

         // offset corresponds to a binary vector
         // returns -1 to indicate that subtraction is not possible
         int subtractindex (unsigned  ind, unsigned  offset) {
             assert (offset < pow(2,dim.size()));
             vector<unsigned > vindex;
             vector<unsigned > twos (dim.size(),2);
             expandindex(ind,vindex);
             bitset<MAXSTRINGS> bindex (offset);
             for (unsigned  i=0; i<dim.size(); i++) {
                  if (vindex[i]==0 && bindex[i]==1)
                      return -1;
                  vindex[i] -= bindex[i];
             }
             return compressindex(vindex);
         }


         E& at(unsigned  ind) {
             return tab[ind];
         }

         E& at(const vector<unsigned >& index) {
             return at(compressindex(index));
         }

     private:
         vector<unsigned > dim;
         vector <E> tab;
};

dmap_t* makedmap (string dfile)
{
    ifstream din(dfile.c_str());
    if (!din.is_open()) {
        cerr << "Warning: Could not open file '" << dfile << "'. Proceeding with defaults.\n";
        return NULL;
    }
    dmap_t* dmap = new dmap_t;
	string line;
	while(getline(din, line)) {
		if(!line.empty()) {
			vector<tok_t> tokens = split(line, ' ');
            assert (tokens.size() == 3);
            pair<tok_t,tok_t> key = make_pair(tokens[0],tokens[1]);
            cost_t d = atof(tokens[2].c_str());
            (*dmap)[key] = d;
        }
    }
    return dmap;
}

cost_t dist(tok_t& t1, tok_t& t2, dmap_t* dmap, cost_t dfltdist)
{
    pair<tok_t,tok_t> key = make_pair(t1,t2);
    if(dmap == NULL || dmap->count(key) == 0)
        return (t1 == t2) ? 0 : dfltdist;
    return dmap->at(key);
}

cost_t distance(vector<tok_t>& tv, dmap_t* dmap = NULL, cost_t dfltdist = default_dist)
{
    cost_t cost = 0;
    for (unsigned  i=0; i < tv.size(); i++)
        for (unsigned  j=i+1; j < tv.size(); j++)
            cost += dist(tv[i],tv[j],dmap,dfltdist);
    return cost;
}


unsigned int align(const vector <vector <tok_t> >& input, const tok_t etok, dmap_t* dmap, vector<vector <tok_t> >& output)
{
    unsigned  n = input.size();
    vector<unsigned > dimensions (n);
    for (unsigned  i=0; i < n; i++)
        dimensions[i] = input[i].size();
    Table<elem_t> table (dimensions);
    table.at(0).revptr = 0; // 0 is NULL
    table.at(0).width = 0;
    table.at(0).cost = 0;

    unsigned  nbhd = pow(2,n);
    unsigned  T = table.size();

    for (unsigned  t=1; t < T; t++) {
        elem_t e;
        vector <unsigned > vt;
        table.expandindex(t,vt);
        bool uninitialized = true;
        for (unsigned  k = 1; k < nbhd; k++) {
            int nbr =  table.subtractindex(t,k);
            if (nbr<0)
                continue;
            // assemble the "current tokens vector"
            vector<tok_t> toks;
            toks.clear(); toks.resize(n);
            bitset<MAXSTRINGS> bk (k);
            for (unsigned  j=0; j < n; j++) {
                toks[j] = ( bk[j] ? input[j][vt[j]] : etok );
            }
            cost_t newcost = distance(toks,dmap) + table.at(nbr).cost;
            if (uninitialized || e.cost > newcost) {
                uninitialized = false;
                e.cost = newcost;
                e.revptr = nbr;
                e.width = table.at(nbr).width + 1;
            }
        }
        table.at(t) = e; 
    }

    // assemble output starting from table.at(T-1)
    unsigned w = table.at(T-1).width;
    output.clear();
    output.resize(n);
    for (unsigned i=0; i < n; i++)
        output[i].resize(w);
    for (unsigned t = T-1; t > 0; t = table.at(t).revptr, w--) {
       assert(w>0);
       unsigned r = table.at(t).revptr;
       vector <unsigned > vt, vr;
       table.expandindex(t,vt);
       table.expandindex(r,vr);
       for (unsigned i=0; i<n; i++) {
            output[i][w-1] = (vt[i]==vr[i] ? etok : input[i][vt[i]] );
       }
    }
    return table.at(T-1).width;
}

int main(int argc, char** argv) 
{
    string argerr = "";

    string distfile = "";
    tok_t emptytok = default_emptytok;
    bool flip = true;

    for (int a=1; a < argc; a++) {
        string arg(argv[a]); 
        if (arg == "--dist") {
             if (++a == argc) argerr = "Missing distance file";
             else distfile = argv[a];
        } else if (arg == "--noflip") {
            flip = false;
        } else if (arg == "--empty") {
            if (++a == argc) argerr = "Missing empty-token";
            else emptytok = argv[a];
        } else
            argerr = "Unknown argument: " + arg;
    }

	if(argerr != "") {
		cerr << "Error: " << argerr << "\nUsage: " << argv[0] << " [--empty empty_token] [--dist <distance file>]\n";
		exit(1);
	}

    dmap_t* dmap = NULL;
    if(distfile != "")
        dmap = makedmap(distfile);

	string line;
    vector <vector <tok_t> > input, output;
	while(getline(cin, line) && input.size() < MAXSTRINGS) {
		if(!line.empty()) {
            line = dummytoken + " " + line;
			vector<tok_t> tokens = split(line, ' ');
            input.push_back(tokens);
        }
    }
    unsigned width = align(input,emptytok,dmap,output);

    if (flip) {
        for (unsigned j=0; j < width; j++) {
            for (unsigned i=0; i < output.size(); i++)
                cout << output[i][j] << "\t"; 
            cout << "\n";
        }
    } else {
        for (unsigned i=0; i < output.size(); i++) {
            for (unsigned j=0; j < width; j++)
                cout << output[i][j] << " "; 
            cout << "\n";
        }
    }
    return 0;
}

