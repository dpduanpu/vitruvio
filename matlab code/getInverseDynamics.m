%% getInverseDynamics

function jointTorque = getInverseDynamics(joint, meanCyclicMotionHipEE, robotConfig, config)

for i = 1:length(joint.LF.rotationalAcceleration(:,1))
   jointVel = joint.LF.rotationalVelocity(i,1:3);
   jointAccel = joint.LF.rotationalAcceleration(i,:);

   wrench = [0 0 0 meanCyclicMotionHipEE.LH.force(i,1:3)]; % need to rotate this force to base frame?
   fext = externalForce(robotConfig,'body4',wrench);
    
   jointTorque(i,:) = inverseDynamics(robotConfig, config(i,:), jointVel,jointAccel, fext);
 end

% inverseDynamics(robot, config)