// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library CertificateStructs {
    struct Certificate {
        string certificateId;
        string examTitle;
        string examDescription;
        string dateIssued;
        string issuer;
        address contractAddress;
    }
}
