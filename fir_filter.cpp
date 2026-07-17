void fir_filter(
    bool rst,
    int input,
    int &output
)
{
#pragma HLS PIPELINE

    static int shift_reg[8];
#pragma HLS RESET variable=shift_reg

    if(rst)
    {
        for(int i=0;i<8;i++)
        {
#pragma HLS UNROLL
            shift_reg[i] = 0;
        }

        output = 0;
        return;
    }

    int coefficient[8] = {1,2,3,4,5,6,7,8};

    int acc = 0;

    for(int i=7;i>0;i--)
    {
#pragma HLS UNROLL
        shift_reg[i] = shift_reg[i-1];
    }

    shift_reg[0] = input;

    for(int i=0;i<8;i++)
    {
#pragma HLS UNROLL
        acc += shift_reg[i] * coefficient[i];
    }

    output = acc;
}