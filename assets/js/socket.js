// NOTE: The contents of this file will only be executed if
// you uncomment its entry in "assets/js/app.js".

// To use Phoenix channels, the first step is to import Socket,
// and connect at the socket path in "lib/web/endpoint.ex".
//
// Pass the token on params as below. Or remove it
// from the params if you are not using authentication.
import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

// When you connect, you'll often need to authenticate the client.
// For example, imagine you have an authentication plug, `MyAuth`,
// which authenticates the session and assigns a `:current_user`.
// If the current user exists you can assign the user's token in
// the connection for use in the layout.
//
// In your "lib/web/router.ex":
//
//     pipeline :browser do
//       ...
//       plug MyAuth
//       plug :put_user_token
//     end
//
//     defp put_user_token(conn, _) do
//       if current_user = conn.assigns[:current_user] do
//         token = Phoenix.Token.sign(conn, "user socket", current_user.id)
//         assign(conn, :user_token, token)
//       else
//         conn
//       end
//     end
//
// Now you need to pass this token to JavaScript. You can do so
// inside a script tag in "lib/web/templates/layout/app.html.eex":
//
//     <script>window.userToken = "<%= assigns[:user_token] %>";</script>
//
// You will need to verify the user token in the "connect/3" function
// in "lib/web/channels/user_socket.ex":
//
//     def connect(%{"token" => token}, socket, _connect_info) do
//       # max_age: 1209600 is equivalent to two weeks in seconds
//       case Phoenix.Token.verify(socket, "user socket", token, max_age: 1209600) do
//         {:ok, user_id} ->
//           {:ok, assign(socket, :user, user_id)}
//         {:error, reason} ->
//           :error
//       end
//     end
//
// Finally, connect to the socket:
socket.connect();

function escapeHtml(unsafe) {
  console.log(unsafe);
  return `${(unsafe||'')}`
       .replace(/&/g, "&amp;")
       .replace(/</g, "&lt;")
       .replace(/>/g, "&gt;")
       .replace(/"/g, "&quot;")
       .replace(/'/g, "&#039;");
};

let LOG = {
  SIM_STEPS: false
};
// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("room:lobby", {});
let chatInput = document.getElementById("chat-input");
let messagesContainer = document.getElementById("messages");
let $vizContainer = document.getElementById('viz-container');

let commandBuffer = [];
let currCommand = 0;

chatInput.addEventListener("keydown", event => {
  var input = chatInput.value.trim();
  if (event.keyCode == 13 && input.length > 0) {
    // record command to buffer and add to cli
    commandBuffer.push(input);
    currCommand = commandBuffer.length-1;

    let messageItem = document.createElement("div");
    messageItem.className = "cli-input";
    messageItem.innerText = `${input}`;
    messagesContainer.appendChild(messageItem);
    chatInput.value = "";

    if (input[0] == '$') {
      // handle client commands
      let jsCode = input.substring(1);
      let ret;
      try {
        ret = eval(jsCode);
      } catch (e) {
        ret = e.toString();
      }      
      messageItem = document.createElement("div");
      messageItem.className = "client-eval";
      messageItem.innerText = `LOCL: ${escapeHtml(ret)}`;
      messagesContainer.appendChild(messageItem);
      scrollToLastMessage();
    } else if (input[0] == '#') {
      // handle server command
      channel.push("server_eval", {body: input.substring(1)});
    } else {
      // handle normal chat msg
      channel.push("new_msg", {body: input});
    }
    event.preventDefault();
  } else if (event.keyCode == 38) { // arrow up
    chatInput.value = commandBuffer[currCommand]  || "";
    currCommand--;
    if (currCommand < 0 ) {
      currCommand = 0;
    }
    event.preventDefault();
  } else if (event.keyCode == 40) { // arrow down    
    if (currCommand < commandBuffer.length ) {
      chatInput.value = commandBuffer[currCommand] || "";
      currCommand++;        
    } else {
      chatInput.value = "";
    }
    event.preventDefault();
  }
});


function scrollToLastMessage() {
  messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

channel.on("new_msg", payload => {
  let messageItem = document.createElement("div")
  messageItem.className = "cli-message";
  messageItem.innerText = `MESG: ${payload.body}`;
  messagesContainer.appendChild(messageItem);
  scrollToLastMessage();
})

channel.on("server_eval_result", payload => {
  let messageItem = document.createElement("div")
  messageItem.className = "server-message";
  messageItem.innerText = `SRVR: ${payload.body}`;
  messagesContainer.appendChild(messageItem);
  scrollToLastMessage();
})

channel.on("server_error_msg", payload => {
  let messageItem = document.createElement("div")
  messageItem.className = "error-message";
  messageItem.innerText = `SRVR: ${payload.body}`;
  messagesContainer.appendChild(messageItem);
  scrollToLastMessage();
})

channel.on("sim_msg", payload => {
  let world = JSON.parse(payload.body);
  if (LOG.SIM_STEPS) {
    console.log(payload.body);
  }
  r_syncScene(world);
})

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) });

import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';

var scene = new THREE.Scene();

scene.add( new THREE.AmbientLight(0x333333));

var directionalLight = new THREE.DirectionalLight( 0xccffff, 0.5 );
directionalLight.position.set(0,1,0);
scene.add( directionalLight );

directionalLight = new THREE.DirectionalLight( 0xffccff, 0.5 );
directionalLight.position.set(0,-1,0);
scene.add( directionalLight );

directionalLight = new THREE.DirectionalLight( 0xffffcc, 0.5 );
directionalLight.position.set(1,0,1);
scene.add( directionalLight );

var collisionsGroup = new THREE.Group();
scene.add(collisionsGroup);

var size = 20;
var divisions = 40;
var gridHelper = new THREE.GridHelper( size, divisions, "#2A2", "#888" );
scene.add( gridHelper );


var camera = new THREE.PerspectiveCamera( 75, 1, 0.1, 1000 );
var renderer = new THREE.WebGLRenderer();

let controls = new OrbitControls( camera, renderer.domElement );



controls.enableDamping = true; // an animation loop is required when either damping or auto-rotation are enabled
controls.dampingFactor = 0.25;
controls.enableKeys = false;
controls.screenSpacePanning = true;
controls.minDistance = 1;
controls.maxDistance = 500;

var activeBodies = {};

function r_createBody(ref, body) {
  let geometry;
  let shape = body.shape;
  switch(shape[0]){
    case "box": geometry = new THREE.BoxGeometry( shape[1], shape[2], shape[3] ); break;
    case "sphere": geometry = new THREE.SphereGeometry(shape[1], 16, 12); break;
    case "capsule":  var createCapsule = require('primitive-capsule');
                     var capsule = createCapsule(shape[2], shape[1]);
                     geometry = new THREE.BufferGeometry();

                     let cells = capsule.cells.reduce( function(acc, el, i) {
                      acc[ (3*i) + 0] = el[0];
                      acc[ (3*i) + 1] = el[1];
                      acc[ (3*i) + 2] = el[2];
                      return acc;
                     }, new Array(capsule.cells.length));

                     let pos = capsule.positions.reduce( function(acc, el, i) {
                      acc[ (3*i) + 0] = el[0];
                      acc[ (3*i) + 1] = el[1];
                      acc[ (3*i) + 2] = el[2];
                      return acc;
                     }, new Float32Array(capsule.positions.length*3));

                     let norms = capsule.normals.reduce( function(acc, el, i) {
                      acc[ (3*i) + 0] = el[0];
                      acc[ (3*i) + 1] = el[1];
                      acc[ (3*i) + 2] = el[2];
                      return acc;
                     }, new Float32Array(capsule.normals.length*3));
                     geometry.setIndex(cells);
                     geometry.addAttribute("position", new THREE.BufferAttribute( pos, 3));
                     geometry.addAttribute("normal", new THREE.BufferAttribute( norms, 3));
                     break;
    default: break;
  }
  
  var color = new THREE.Color( 0xffffff );
  color.setHex( Math.random() * 0xffffff );
  var material = new THREE.MeshPhongMaterial( { color: color, wireframe: true } );
  var object = new THREE.Mesh( geometry, material );
  object.position.set(body.position[0], body.position[1], body.position[2])
  object.setRotationFromQuaternion( new THREE.Quaternion(body.orientation[1],body.orientation[2],body.orientation[3],body.orientation[0]))

  activeBodies[ref] = object;
  scene.add( object );
}

function r_updateBody(ref, body) {
  activeBodies[ref].position.set(body.position[0], body.position[1], body.position[2]);  
  activeBodies[ref].setRotationFromQuaternion( new THREE.Quaternion(body.orientation[1],body.orientation[2],body.orientation[3],body.orientation[0]))
}

function r_destroyBody(ref) {
  let body = activeBodies[ref];
  if (body) {
    scene.remove(body);
    delete activeBodies[ref];
  }
}

function r_syncScene(world) {
  var bodies = world.bodies;

  var vizRefs = Object.keys(activeBodies);
  var simRefs = Object.keys(bodies);

  // check for updated or destroyed bodies
  for( let vref in vizRefs) {
    if ( simRefs.includes(vizRefs[vref]) == true ){
      r_updateBody(vizRefs[vref], bodies[vizRefs[vref]]);
    } else {
      r_destroyBody(vizRefs[vref]);
    }
  }

  // check for created bodies
  for( let sref in simRefs) {
    if ( vizRefs.includes(simRefs[sref]) == false){
      r_createBody(simRefs[sref],bodies[simRefs[sref]]);
    }
  }

  // show the collision info
  collisionsGroup.children.forEach( (c) => collisionsGroup.remove(c) );
  for( let c_index in world.collisions) {
    // c = {:contact_manifold, [{contacts}], world_normal}
    //  @type contact_point :: record(:contact_point, world_point: Vec3.vec3(), depth: number)
    var c = world.collisions[c_index];

    console.log(c);
    var normal = (new THREE.Vector3()).fromArray(c[2]);
    var contacts = c[1];
    var contactPoint = contacts[0][1];
    var length = 1.0;
    var point = new THREE.ArrowHelper(normal, (new THREE.Vector3()).fromArray(contactPoint), length);
    collisionsGroup.add(point);
  }
}

function animate() {
  requestAnimationFrame( animate );
  controls.update(); // only required if controls.enableDamping = true, or if controls.autoRotate = true
	renderer.render( scene, camera );
}
animate();

$vizContainer.appendChild( renderer.domElement );
let vizDimensions = $vizContainer.getBoundingClientRect();
renderer.setSize( vizDimensions.width, vizDimensions.height );

export default socket;
