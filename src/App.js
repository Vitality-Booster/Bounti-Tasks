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
  const taskStatusArray = ["Pending", "In progress", "Review", "Completed"];

  const [daoContract, setDaoContract] = useState("");
  const [taskName, setTaskName] = useState("");
  const [taskDescription, setTaskDescription] = useState("");
  const [taskDetails, setTaskDetails] = useState("");
  const [taskStatus, setTaskStatus] = useState("");
  const [taskReward, setTaskReward] = useState(0);
  const [percentageForReviewers, setPercentageForReviewers] = useState(0);
  const [taskLevel, setTaskLevel] = useState("");
  const [taskSectionId, setTaskSectionId] = useState("");
  const [taskId, setTaskId] = useState("");
  const [taskCID, setTaskCID] = useState("");
  const [taskOwner, setTaskOwner] = useState("");
  const [taskReviewers, setTaskReviewers] = useState([]);
  const [taskWorkers, setTaskWorkers] = useState([]);

  // Variables for smart contract
  const contractAddress = "0x94c9805Eb10d93a64fA5c15D5f6f0B565782f7CC";
  const contractABI = abi.abi;

  // Login function, Moralis
  const login = async () => {
    if (!isAuthenticated) {
      await authenticate({ signingMessage: "Log in using Moralis" })
          .catch(function (error) {
            console.log(error);
          });
    }
  };

  // Returns Bounti Contract
  const getBountiContract = async () => {
    const { ethereum } = window;
    const provider = new ethers.providers.Web3Provider(ethereum);
    const signer = provider.getSigner();
    const bountiContract = new ethers.Contract(contractAddress, contractABI, signer);

    return bountiContract;
  }

  const logOut = async () => {
    await logout();
  };

  //   Creates a new Task and uploads task data to IPFS, Moralis and Avax
  const createTask = async () => {
    const Task = Moralis.Object.extend("Task");
    const task = new Task();

      console.log("Task Name: ", taskName)
      console.log("Task Description: ", taskDescription)
      console.log("Task Details: ", taskDetails)
      console.log("Task Level: ", taskLevel)
      console.log("Task Section ID: ", taskSectionId)

    const metadata = {
      name: taskName,
      description: taskDescription,
      details: taskDetails,
      level: taskLevel,
      sectionId: taskSectionId,
    };


    const file = new Moralis.File("file.json", {
      base64: btoa(JSON.stringify(metadata)),
    });

    await file.saveIPFS();

    task.set("CID", file.hash());
    task.save()
        .then( async (task) => {
          await setTaskId(task.id);
          console.log("Task ID: ", taskId)
          await addTaskToAvax(task.id);
        })
        .catch(err => {
          alert(err.data.message);
        })
  };

    // Adding a task to the blockchain
    const addTaskToAvax = async (id) => {
        const contract = await getBountiContract();

        console.log("Id in Avax addTask: ", id)

        await contract.createTask(daoContract, id, taskReward, percentageForReviewers);
    }

  const addWorker = async () => {
    const contract = await getBountiContract();

    contract.addWorker(taskId)
        .catch(err => {
          alert(err.data.message)
        });
  }

  const addReviewer = async () => {
    const contract = await getBountiContract();

    contract.addReviewer(taskId)
        .catch(err => {
          alert(err.data.message)
        });
  }

  const removeWorker = async () => {
    const contract = await getBountiContract();

    contract.removeWorker(taskId)
        .catch(err => {
          alert(err.data.message)
        });
  }

  const removeReviewer = async () => {
    const contract = await getBountiContract();

    contract.removeReviewer(taskId)
        .catch(err => {
          alert(err.data.message)
        });
  }

  const removeTask = async () => {
    const contract = await getBountiContract();

    contract.removeTask(taskId)
        .catch(err => {
          alert(err.data.message)
        });
  }

  const getSingleTask = async () => {

      // Getting data from smart contract
    const contract = await getBountiContract();
    console.log("Task Id that I get in getSingleTask: ", taskId)

    contract.getTask(taskId)
        .then( async (allData) => {
          const taskData = allData[0];
          const workers = allData[1];
          const reviewers = allData[2];

          await setDaoContract(taskData.daoContract);
          await setTaskOwner(taskData.taskOwner);
          await setTaskReward(taskData.prize);
          await setPercentageForReviewers(taskData.percentageForReviewers);
          await setTaskStatus(taskStatusArray[taskData.status]);

          console.log("TaskData: ", taskData);
          console.log("Workers: ", workers);
          console.log("Reviewers: ", reviewers);
          setTaskWorkers(workers);
          setTaskReviewers(reviewers);
        })
        .catch(err => {
          alert(err.data.message)
        });

    // Getting data from Moralis
    const Task = Moralis.Object.extend("Task");
    const query = new Moralis.Query(Task);
    const taskMoralis = await query.get(taskId);
    await setTaskCID(taskMoralis.attributes.CID);
    const cid = taskMoralis.attributes.CID;

    // Getting data from IPFS
    const url = `https://gateway.moralisipfs.com/ipfs/${cid}`;
    const response = await fetch(url);
    const task = await response.json();

    console.log("The whole Task that I get from IPFS: ", task)

    console.log("The Task Name that I get from IPFS: ", task.name)

    await setTaskName(task.name);
    await setTaskDescription(task.description);
    await setTaskDetails(task.details);
    await setTaskLevel(task.level);
    await setTaskSectionId(task.sectionId);
  }

  return (
      <div className="App pb-3">
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
              <FormControl className="" type="text" placeholder="0xa9****"
                           onChange={e => setDaoContract(e.target.value)} value={daoContract}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task name:</FormLabel>
              <FormControl className="" type="text" placeholder="Task name"
                           onChange={e => setTaskName(e.target.value)} value={taskName}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task description:</FormLabel>
              <FormControl className="" as="textarea" placeholder="Description"
                           onChange={e => setTaskDescription(e.target.value)} value={taskDescription}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task details:</FormLabel>
              <FormControl className="" type="text" placeholder="Task details"
                           onChange={e => setTaskDetails(e.target.value)} value={taskDetails}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task status:</FormLabel>
              <FormControl className="" type="text" placeholder="Pending"
                           value={taskStatus} readOnly />
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task reward:</FormLabel>
              <FormControl className="" type="number" placeholder="100"
                           onChange={e => setTaskReward(parseInt(e.target.value.trim()))} value={taskReward}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Percentage for reviewers:</FormLabel>
              <FormControl className="" type="number" placeholder="100"
                           onChange={e => setPercentageForReviewers(parseInt(e.target.value.trim()))}
                           value={percentageForReviewers}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task level:</FormLabel>
              <FormControl className="" type="text" placeholder="General"
                           onChange={e => setTaskLevel(e.target.value)} value={taskLevel}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task section ID:</FormLabel>
              <FormControl className="" type="text" placeholder="Ja6Hee12"
                           onChange={e => setTaskSectionId(e.target.value)} value={taskSectionId}/>
            </FormGroup>
          </Col>
        </Row>
        <Row className="justify-content-center my-3">
          <Col sm="4">
            <FormGroup>
              <FormLabel style={{fontSize: '30px', color: 'wheat'}}>Task ID:</FormLabel>
              <FormControl className="" type="text" placeholder="-----"
                           onChange={e => setTaskId(e.target.value)} value={taskId}/>
            </FormGroup>
          </Col>
        </Row>
        <Button className="mx-3 mb-3" variant="primary" onClick={createTask}>Create task</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={addWorker}>Add worker</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={addReviewer}>Add reviewer</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={removeWorker}>Remove worker</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={removeReviewer}>Remove reviewer</Button>
        <Button className="mx-3 mb-3" variant="primary" onClick={getSingleTask}>Get single task</Button>
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
