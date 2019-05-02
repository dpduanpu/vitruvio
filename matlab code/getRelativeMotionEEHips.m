%% Get relative motion of end effectors to the hips

function [relativeMotionHipEE, IF_hip] = getRelativeMotionEEHips(quat, quadruped, base, EE)

%% get hip positions

%load quaternion for each time step into q. These describe rotations of the
%center of mass in the inertial frame

%quat =  [orientation w, orientation x, orientation y, orientation z]
% take negative of rotation angles because now we are rotating back from
% body frame to inertial frame?

%% Convert quaternion to rotation matrix and get hip positions in world frame
% R = quat2rotm(Q) converts a plotunit quaternion, Q, into an orthonormal
%     rotation matrix, R. The input, Q, is an N-by-4 matrix containing N quaternions. 
%     Each quaternion represents a 3D rotation and is of the form q = [w x y z], 
%     with a scalar number as the first value. Each element of Q must be a real number.
%     The output, R, is an 3-by-3-by-N matrix containing N rotation matrices.


%rotated_hip position is the sum of the CoM position and the offset from
%CoM to each of the hips. This represents the position of each hip in the
%inertial frame

%% calculate hip positions in inertia frame

% first calculate hip position relative to center of mass then add the
% center of mass position in inertia frame. This gives the hip position in
% inertia frame

% nomHipPos is a vector from CoM to the hip attachment point. This is a
% fixed value based on the quadruped properties

for i = 1:length(quat)
C_IBody(:,:,i) = quat2rotm(quat(i,:));                                                              
IF_hip.LF.position(i,:) = quadruped.nomHipPos(1,:)*C_IBody(:,:,i) + [base.position(i,1) base.position(i,2) base.position(i,3)];
IF_hip.LH.position(i,:) = quadruped.nomHipPos(2,:)*C_IBody(:,:,i) + [base.position(i,1) base.position(i,2) base.position(i,3)];
IF_hip.RF.position(i,:) = quadruped.nomHipPos(3,:)*C_IBody(:,:,i) + [base.position(i,1) base.position(i,2) base.position(i,3)];
IF_hip.RH.position(i,:) = quadruped.nomHipPos(4,:)*C_IBody(:,:,i) + [base.position(i,1) base.position(i,2) base.position(i,3)];
end

% we have coordinates of each foot and hip in inertia frame, subtracting
% them gives the relative position and velocity of the feet to the hips.
% This simulates a fixed hip allowing observation of the foot position.

relativeMotionHipEE.LF.position = EE.LF.position - IF_hip.LF.position;
relativeMotionHipEE.LH.position = EE.LH.position - IF_hip.LH.position;
relativeMotionHipEE.RF.position = EE.RF.position - IF_hip.RF.position;
relativeMotionHipEE.RH.position = EE.RH.position - IF_hip.RH.position;