package ed25519_ht_scalar_sched_pkg;
    typedef enum logic [4:0] {
        OP_NONE,
        OP_MADD_A,
        OP_MADD_B,
        OP_MADD_C,
        OP_MADD_X,
        OP_MADD_Y,
        OP_MADD_Z,
        OP_MADD_T
    } scalar_mul_op_t;

    typedef struct packed {
        logic [4:0]       ctx;
        scalar_mul_op_t   op;
    } scalar_mul_tag_t;
endpackage
