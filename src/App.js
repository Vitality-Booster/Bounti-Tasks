import './App.css';
import React, { useEffect, useState, useRef } from "react";
import { useMoralis } from "react-moralis";
import { Moralis } from "moralis";
import abi from "./utils/TaskManager.json";
import {Button, Col, Figure, FormControl, FormGroup, FormLabel, Row} from "react-bootstrap";
// import FigureImage from "react-bootstrap/FigureImage";

function App() {
  const {
    authenticate,
    isAuthenticated,
    isAuthenticating,
    user,
    // account,
    logout,
  } = useMoralis();

  const ethers = Moralis.web3Library;

  // const [daoContract, setDaoContract] = useState("");
  // const [taskName, setTaskName] = useState("");
  // const [taskDescription, setTaskDescription] = useState("");
  // const [taskStatus, setTaskStatus] = useState("");
  // const [taskReward, setTaskReward] = useState("");
  // const [taskLevel, setTaskLevel] = useState("");
  // const [taskSectionId, setTaskSectionId] = useState("");
  // const [taskId, setTaskId] = useState("");
  // const [taskCID, setTaskCID] = useState("");

  // !!! It was mentioned in some website that useState is async and useRef in sync,
  // maybe that is why useState variable didn't manage to update their values in Dante's section !!!

  // Trying to use Refs instead of States

  const daoContract = useRef();
  const taskName = useRef();
  const taskDescription = useRef();
  const taskDetails = useRef();
  const taskStatus = useRef();
  const taskReward = useRef();
  const taskLevel = useRef();
  const taskSectionId = useRef();
  const taskId = useRef();
  const taskCID = useRef();
  const taskOwner = useRef();
  const taskReviewers = useRef();
  const taskWorkers = useRef();


  //variables for smart contract
  const contractAddress = "0xa38Dc7585Cd833c89D5449a85ff71685cbe739E0";
  const contractABI = abi.abi;

  //login function Moralis
  const login = async () => {
    if (!isAuthenticated) {
      await authenticate({ signingMessage: "Log in using Moralis" })
          .catch(function (error) {
            console.log(error);
          });
    }
  };

  useEffect(() => {
    //getAllDAOs();
  }, [])

  const logOut = async () => {
    await logout();
  };

  //   Upload metadata object: name, description, image
  const uploadMetadata = async () => {
    const DAO = Moralis.Object.extend("DAOs");
    const dao = new DAO();
    const name = document.getElementById("DAOname").value;
    const tag = document.getElementById("DAOtag").value;
    const description = document.getElementById("DAOdesc").value;
    const tech = document.getElementById("DAOtech").value;
    const contract = document.getElementById("DAOcontract").value;
    const site = document.getElementById("DAOsite").value;
    const signature = document.getElementById("DAOsignature").value;
    const sections = document.getElementById("DAOsections").value;

    const metadata = {
      name: name,
      tag: tag,
      description: description,
      tech: tech,
      site: site,
      signature: signature,
      sections: sections,
    };

    const file = new Moralis.File("file.json", {
      base64: btoa(JSON.stringify(metadata)),
    });

    await file.saveIPFS();

    dao.set("CID", file.hash());
    dao.set("contractAddress", contract);
    await dao.save();
  };

  //Function to upload
  const upload = async () => {
    await uploadMetadata();
    await addDAO();
  };

  //Function to get saved info from ipfs
  const getDAOIpfs = async () => {
    const query = new Moralis.Query("DAOs");

    const daoContract = document.getElementById("SelectedDAO").value;
    query.equalTo("contractAddress", daoContract);
    const dao = await query.first();
    const daoCID = dao.attributes.CID;
    const url = `https://gateway.moralisipfs.com/ipfs/${daoCID}`;
    const response = await fetch(url);
    setIpfsDAO(await response.json());
    //console.log(response.json());
  };

  //get single dao & members from that dao
  const getDAO = async () => {
    const { ethereum } = window;
    if (ethereum) {
      const provider = new ethers.providers.Web3Provider(ethereum);
      const signer = provider.getSigner();
      const bountiContract = new ethers.Contract(contractAddress, contractABI, signer);
      const daoContract = document.getElementById("SelectedDAO").value;
      const dao = await bountiContract.getDao(daoContract);
      setDao(dao);
      //console.log(dao);
    }
  }

  //getting all daos from the blockchain
  const getAllDAOs = async () => {
    const { ethereum } = window;
    if (ethereum) {
      const provider = new ethers.providers.Web3Provider(ethereum);
      const signer = provider.getSigner();
      const bountiContract = new ethers.Contract(contractAddress, contractABI, signer);

      const daos = await bountiContract.getAllDaos();
      setDaos(daos);
    }
  }

  const getAllDAOsN = async () => {
    const allDaos = [];
    const { ethereum } = window;
    if (ethereum) {
      const provider = new ethers.providers.Web3Provider(ethereum);
      const signer = provider.getSigner();
      const bountiContract = new ethers.Contract(contractAddress, contractABI, signer);
      const bc = await bountiContract.getAllDaos();

      for (const dao of bc) {
        const query = new Moralis.Query("DAOs");
        //query.include(dao.contractAddress);
        query.equalTo("contractAddress", dao.contractAddress);
        console.log(dao.contractAddress)
        const foundDAO = await query.find();
        console.log(foundDAO)
        const foundDAOCID = foundDAO[0].attributes.CID;
        const url = `https://gateway.moralisipfs.com/ipfs/${foundDAOCID}`;
        const response = await fetch(url);
        //console.log(response.json())
        const fullDAO = {
          bc: dao,
          ipfs: await response.json()
        }

        allDaos.push(fullDAO)
        console.log(fullDAO)
      };
    }
    setDaos(allDaos);
  }

  //adding dao to blockchain
  const addDAO = async () => {
    const { ethereum } = window;
    const provider = new ethers.providers.Web3Provider(ethereum);
    const signer = provider.getSigner();
    const bountiContract = new ethers.Contract(contractAddress, contractABI, signer);
    const daoContract = document.getElementById("DAOcontract").value;

    await bountiContract.addDao(daoContract);
  }

  // joining a dao
  const JoinDAO = async () => {
    const { ethereum } = window;
    const provider = new ethers.providers.Web3Provider(ethereum);
    const signer = provider.getSigner();
    const bountiContract = new ethers.Contract(contractAddress, contractABI, signer);
    const daoContract = document.getElementById("DAOcontract").value;

    await bountiContract.joinDao(daoContract);
  }
  return (
      <div className="pb-3">
        <h1 className="py-3" style={{color: 'white'}}>Create Task</h1>
        <Button variant="primary" onClick={login}>Metamask Login</Button>
        <Button className="mx-3" variant="danger" onClick={logOut} disabled={isAuthenticating}>
          Logout
        </Button>
        {/*<h2 className="mt-3" style={{color: 'wheat'}}>All DAOs</h2>*/}
        {/*{daos.map((dao, index) => {*/}
        {/*  return (*/}
        {/*      <div className="mx-5" key={index} style={{ backgroundColor: "OldLace", marginTop: "16px", padding: "8px" }}>*/}
        {/*        <div>Name: {user.name}</div>*/}
        {/*        <div>Address: {user.userAddress}</div>*/}
        {/*      </div>)*/}
        {/*})}*/}
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>DAO contract:</FormLabel>
              <FormControl className="" type="text" placeholder="0xa9****" value={daoContract.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task name:</FormLabel>
              <FormControl className="" type="text" placeholder="Task name" value={taskName.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task description:</FormLabel>
              <FormControl className="" as="textarea" placeholder="Description" value={taskDescription.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task details:</FormLabel>
              <FormControl className="" type="text" placeholder="Task details" value={taskDetails.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task status:</FormLabel>
              <FormControl className="" type="text" placeholder="Pending" value={taskStatus.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task reward:</FormLabel>
              <FormControl className="" type="text" placeholder="100" value={taskReward.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task level:</FormLabel>
              <FormControl className="" type="text" placeholder="General" value={taskLevel.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task section ID:</FormLabel>
              <FormControl className="" type="text" placeholder="Ja6Hee12" value={taskSectionId.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task ID:</FormLabel>
              <FormControl className="" type="text" placeholder="-----" readOnly value={taskId.current}/>
            </FormGroup>
          </Col>
        </Row>
        <Button className="mx-3 mb-3" variant="primary" onClick={createTask}>Create task</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={addWorker}>Create task</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={addReviewer}>Create task</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={removeWorker}>Create task</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={removeReviewer}>Create task</Button>
        {/* <Row className="justify-content-center my-3">
            <Col sm="4">
                <FormGroup>
                    <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Get the CID based on Users name:</FormLabel>
                    <FormControl className="" type="text" id="userName" placeholder="Name"/>
                </FormGroup>
            </Col>
        </Row>
      <Button className="mx-3 mb-3" variant="primary" onClick={get}>Get</Button>
        {
            gotInfo &&
            <div className="pb-3">
                <Row className="justify-content-center my-3">
                    <FormLabel style={{fontSize: '30px', color: 'wheat'}}>{ipfsUser.name}'s image</FormLabel>
                    <Figure>
                        <FigureImage src={ipfsUser.image} />
                    </Figure>
                </Row>
                <Row className="justify-content-center my-3">
                    <Col sm="4">
                        <FormGroup>
                            <FormLabel style={{fontSize: '30px', color: 'wheat'}}>{ipfsUser.name}'s Description</FormLabel>
                            <FormControl className="" as="textarea" value={ipfsUser.description} readOnly={true}/>
                        </FormGroup>
                    </Col>
                </Row>
            </div>
        } */}
      </div>
  );
}
export default App;
