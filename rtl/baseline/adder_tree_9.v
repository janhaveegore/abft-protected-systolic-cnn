`include "cnn_params.vh"
module adder_tree_9(input wire [(`K_SIZE*`PROD_W)-1:0] p_flat, output wire signed [`ACC_W-1:0] sum);
    wire signed [`PROD_W-1:0] p0,p1,p2,p3,p4,p5,p6,p7,p8;
    assign p0=p_flat[1*`PROD_W-1 -: `PROD_W]; assign p1=p_flat[2*`PROD_W-1 -: `PROD_W];
    assign p2=p_flat[3*`PROD_W-1 -: `PROD_W]; assign p3=p_flat[4*`PROD_W-1 -: `PROD_W];
    assign p4=p_flat[5*`PROD_W-1 -: `PROD_W]; assign p5=p_flat[6*`PROD_W-1 -: `PROD_W];
    assign p6=p_flat[7*`PROD_W-1 -: `PROD_W]; assign p7=p_flat[8*`PROD_W-1 -: `PROD_W];
    assign p8=p_flat[9*`PROD_W-1 -: `PROD_W];
    wire signed [`TREE_L0_W-1:0] l0_0,l0_1,l0_2,l0_3,l0_4;
    assign l0_0=p0+p1; assign l0_1=p2+p3; assign l0_2=p4+p5; assign l0_3=p6+p7;
    assign l0_4={{(`TREE_L0_W-`PROD_W){p8[`PROD_W-1]}},p8};
    wire signed [`TREE_L1_W-1:0] l1_0,l1_1,l1_2;
    assign l1_0=l0_0+l0_1; assign l1_1=l0_2+l0_3;
    assign l1_2={{(`TREE_L1_W-`TREE_L0_W){l0_4[`TREE_L0_W-1]}},l0_4};
    wire signed [`TREE_L2_W-1:0] l2_0,l2_1;
    assign l2_0=l1_0+l1_1;
    assign l2_1={{(`TREE_L2_W-`TREE_L1_W){l1_2[`TREE_L1_W-1]}},l1_2};
    wire signed [`TREE_L3_W-1:0] l3; assign l3=l2_0+l2_1;
    assign sum=l3[`ACC_W-1:0];
endmodule
