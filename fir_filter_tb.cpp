#include <iostream>
using namespace std;

void fir_filter(bool rst, int input, int &output);

int main()
{
    int output;

    fir_filter(true,0,output);

    for(int i=0;i<8;i++)
    {
        fir_filter(false,1,output);
        cout << output << endl;
    }

    fir_filter(true,0,output);

    fir_filter(false,1,output);

    cout << "After reset = "
         << output
         << endl;

    return 0;
}