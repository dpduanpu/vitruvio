function Leg = runDataExtractionAndOptScripts(actuatorSelection, dataExtraction, imposeJointLimits, heuristic, actuateJointDirectly, transmissionMethod, viewVisualization, numberOfStepsVisualized, linkCount, runOptimization, optimizeLeg, optimizationProperties, dataSelection, classSelection, configSelection, hipParalleltoBody, legCount, task, saveFiguresToPDF, springInParallelWithJoints, kSpringJoint)

%% Display selections
fprintf('Robot class: %s.\n', classSelection);
fprintf('Task: %s.\n', task);
fprintf('Actuator HAA: %s.\n', actuatorSelection.HAA);
fprintf('Actuator HFE: %s.\n', actuatorSelection.HFE);
fprintf('Actuator KFE: %s.\n', actuatorSelection.KFE);
if linkCount > 2
    fprintf('Actuator AFE: %s.\n', actuatorSelection.AFE);
    if linkCount == 4
        fprintf('Actuator DFE: %s.\n', actuatorSelection.DFE);
    end
end
if linkCount == 2
    fprintf('Links: hip, thigh, shank.\n')
elseif linkCount == 3
    fprintf('Links: hip, thigh, shank, foot.\n')
elseif linkCount == 4
    fprintf('Links: hip, thigh, shank, foot, phalanges.\n')
end

if hipParalleltoBody
    fprintf('Hip parallel to body, serial leg configuration. \n\n');
else
    fprintf('Hip perpendicular to body, spider leg configuration. \n\n');
end

%% Load in trajectory
EEnames = ['LF'; 'RF'; 'LH'; 'RH']; % a subset of these are used depending on legCount
linkNames = {'hip' 'thigh' 'shank' 'foot' 'phalanges'}; % a subset of these are used depending on linkCount
jointNames = ['HAA'; 'HFE'; 'KFE'; 'AFE'; 'DFE']; % a subset of these are used depending on linkCount
jointCount = linkCount + 1; % Due to HAA there is always one more joint than link

% Load motion and force data from .mat file
load(dataSelection);
dt = t(2) - t(1); % time step is constant 
Leg.time = t;
for i = 1:legCount
    EEselection = EEnames(i,:); 
    Leg.(EEselection).force = trajectoryData.(EEselection).force;
end

% Get suggested removal ratio for cropping motion data to useful steady state motion
[removalRatioStart, removalRatioEnd] = getSuggestedRemovalRatios(dataSelection);

%% Load corresponding robot properties
fprintf('Loading quadruped properties for %s.\n', classSelection);
robotProperties = getRobotProperties(classSelection, transmissionMethod, actuateJointDirectly, jointNames, linkNames, linkCount);

% Torsional spring parameters
if linkCount > 2 && heuristic.torqueAngle.apply
    for i = 1:legCount
        EEselection = EEnames(i,:);
        Leg.(EEselection).spring.nominalParameters.kTorsionalSpring = heuristic.torqueAngle.kTorsionalSpring;
        Leg.(EEselection).spring.nominalParameters.thetaLiftoff_des = heuristic.torqueAngle.thetaLiftoff_des;
    end
end

% Actuator properties
fprintf('Loading actuator properties \n');
for i = 1:jointCount
    jointSelection = jointNames(i,:);
    actuatorName = actuatorSelection.(jointSelection);
    [actuatorProperties.maxTorqueLimit.(jointSelection), actuatorProperties.maxqdotLimit.(jointSelection), actuatorProperties.maxPowerLimit.(jointSelection), actuatorProperties.mass.(jointSelection), actuatorProperties.gearRatio.(jointSelection), actuatorProperties.efficiencyMinMotor.(jointSelection), actuatorProperties.efficiencyMaxMotor.(jointSelection)] = getActuatorProperties(actuatorName);
end
Leg.actuatorProperties = actuatorProperties;
Leg.actuatorProperties.actuatorSelection = actuatorSelection;

for i = 1:legCount
    EEselection = EEnames(i,:);
    % Read in joint angle limits.
    Leg.(EEselection).qLimits.min = [robotProperties.q1.minAngle, robotProperties.q2.minAngle, robotProperties.q3.minAngle];
    Leg.(EEselection).qLimits.max = [robotProperties.q1.maxAngle, robotProperties.q2.maxAngle, robotProperties.q3.maxAngle];
    if linkCount > 2
        Leg.(EEselection).qLimits.min = [Leg.(EEselection).qLimits.min, robotProperties.q4.minAngle];
        Leg.(EEselection).qLimits.max = [Leg.(EEselection).qLimits.max, robotProperties.q4.maxAngle];
    end
    if linkCount > 3
        Leg.(EEselection).qLimits.min = [Leg.(EEselection).qLimits.min, robotProperties.q5.minAngle];
        Leg.(EEselection).qLimits.max = [Leg.(EEselection).qLimits.max, robotProperties.q5.maxAngle];       
    end
    
    % Read in link lengths
     if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
         selectFrontHind = 1;
     else
         selectFrontHind = 2;
     end
     for j = 1:jointCount
        Leg.(EEselection).linkLengths(1,j) = robotProperties.(linkNames{j})(selectFrontHind).length;
    end
end

%% Save robot basic properties into struct
Leg.basicProperties.classSelection = classSelection;
Leg.basicProperties.optimizedLegs  = optimizeLeg;
Leg.basicProperties.legCount       = legCount;
Leg.basicProperties.linkCount      = linkCount;
Leg.basicProperties.EEnames        = EEnames(1:legCount,:);
Leg.basicProperties.linkNames      = linkNames(1:jointCount)';
Leg.basicProperties.jointNames     = jointNames(1:jointCount,:);
Leg.basicProperties.trajectory.removalRatioStart = removalRatioStart;
Leg.basicProperties.trajectory.removalRatioEnd   = removalRatioEnd;
Leg.basicProperties.trajectory.averageStepsForCyclicalMotion = dataExtraction.averageStepsForCyclicalMotion;
for i = 1:legCount
    EEselection = EEnames(i,:);
    if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
        Leg.(EEselection).hipAttachmentOffset = -robotProperties.hipOffset(1);
    elseif strcmp(EEselection,'LH') || strcmp(EEselection,'RH')
        Leg.(EEselection).hipAttachmentOffset = robotProperties.hipOffset(2);
    end
end

% Transmission properties
for i = 1:jointCount
    jointSelection = jointNames(i,:);
    if actuateJointDirectly.(jointSelection)
        Leg.basicProperties.jointActuationType.(jointSelection) = 'direct';
        Leg.basicProperties.transmissionMethod.(jointSelection) = 'N/A';
    else 
        Leg.basicProperties.jointActuationType.(jointSelection) = 'remote';
        Leg.basicProperties.transmissionMethod.(jointSelection) = transmissionMethod.(jointSelection);
    end    
end

for i = 1:legCount
    EEselection = EEnames(i,:);
    if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
         selectFrontHind = 1;
     else
         selectFrontHind = 2;
    end
    Leg.(EEselection).transmissionGearRatio = robotProperties.transmissionGearRatio.HAA(selectFrontHind);
    for j = 2:linkCount+1
        Leg.(EEselection).transmissionGearRatio  = [Leg.(EEselection).transmissionGearRatio, robotProperties.transmissionGearRatio.(jointNames(j,:))(selectFrontHind)];
    end
end

%% Save optimization settings
Leg.optimizationProperties.penaltyWeight = optimizationProperties.penaltyWeight;
Leg.optimizationProperties.imposeJointLimits = imposeJointLimits;
Leg.optimizationProperties.allowableExtension = optimizationProperties.allowableExtension;

%% Reconstruct terrain map from EE force and position data
% This feature is in progress.
% terrainMap = constructTerrainMap(trajectoryData, legCount, EEnames);

%% Save the inertial frame EE position data
for i = 1:legCount
    EEselection = EEnames(i,:);
    Leg.inertialFrame.EEposition.(EEselection) = trajectoryData.(EEselection).position;
end

%% Get the relative motion of the end effectors to the hips
fprintf('Computing motion of end effectors relative to hip attachment points. \n');
[relativeMotionHipEE, IF_hip, C_IBody] = getRelativeMotionEEHips(quat, robotProperties, trajectoryData, dt, EEnames, legCount);

%% Get deviation from neighbouring point
setOfNeighbouringPointDeviationMax = [];
for i = 1:legCount
    EEselection = EEnames(i,:);
    [neighbouringPointDeviation.(EEselection), neighbouringPointDeviationMax.(EEselection)] = getDeviationFromNeighbouringPoint(relativeMotionHipEE, EEselection);
    Leg.metaParameters.neighbouringPointDeviation.(EEselection) = neighbouringPointDeviation.(EEselection);
    Leg.metaParameters.neighbouringPointDeviationMax.(EEselection) = neighbouringPointDeviationMax.(EEselection);
    setOfNeighbouringPointDeviationMax = [setOfNeighbouringPointDeviationMax, neighbouringPointDeviationMax.(EEselection)];
end

%% If points are spread too far apart, interpolate to add more points
allowableDeviation = dataExtraction.allowableDeviation;
absoluteMaxPointDeviation = max(setOfNeighbouringPointDeviationMax); % the absolute max deviation for all legs
if absoluteMaxPointDeviation > allowableDeviation
    numberOfTimesPointsAreDoubled = ceil(log(absoluteMaxPointDeviation/allowableDeviation)/log(2)); % because deviation decreases by factor of 2^n
    fprintf('Interpolating points to reduce distance between neighbouring points to less than %2.3fm. \n', allowableDeviation);
    for j = 1:numberOfTimesPointsAreDoubled
        for i = 1:legCount
            EEselection = EEnames(i,:);
            [relativeMotionHipEE.(EEselection).position, relativeMotionHipEE.(EEselection).velocity, trajectoryData.(EEselection).force, ~, ~] = generateAdditionalPoints(relativeMotionHipEE, trajectoryData, C_IBody, EEselection);
        end
        [~, ~, ~, C_IBody, trajectoryData.base.position] = generateAdditionalPoints(relativeMotionHipEE, trajectoryData, C_IBody, EEselection);                         
        dt = dt/2;
        Leg.time = [0:dt:t(end)]';
    end
    % Recompute the deviation from neighbouring point
    for i = 1:legCount
        EEselection = EEnames(i,:);
        [neighbouringPointDeviation.(EEselection), neighbouringPointDeviationMax.(EEselection)] = getDeviationFromNeighbouringPoint(relativeMotionHipEE, EEselection);
        Leg.metaParameters.neighbouringPointDeviation.(EEselection) = neighbouringPointDeviation.(EEselection);
        Leg.metaParameters.neighbouringPointDeviationMax.(EEselection) = neighbouringPointDeviationMax.(EEselection);
    end
end

%% Compute centre of mass velocity and acceleration using finite differences
trajectoryData.base.velocity     = diff(trajectoryData.base.position)/dt;
trajectoryData.base.acceleration = diff(trajectoryData.base.velocity)/dt;

%% Full trajectory position and forces after point interpolation
Leg.fullTrajectory.base.position = trajectoryData.base.position;
Leg.fullTrajectory.base.velocity = diff(trajectoryData.base.position)/dt;
for i = 1:legCount
    EEselection = EEnames(i,:);
    Leg.fullTrajectory.force.(EEselection)   = trajectoryData.(EEselection).force;
    Leg.fullTrajectory.r.EEdes.(EEselection) = relativeMotionHipEE.(EEselection).position;
end

%% Get the liftoff and touchdown timings for each end effector
fprintf('Computing end effector liftoff and touchdown timings. \n');
minStepCount = [];
for i = 1:legCount
    EEselection = EEnames(i,:);  
    force = Leg.fullTrajectory.force.(EEselection);
    [tLiftoff.(EEselection), tTouchdown.(EEselection), minStepCountTemp] = getEELiftoffTouchdownTimings(Leg.time, force);
    minStepCount = [minStepCount, minStepCountTemp];
end
minStepCount = min(minStepCount);
Leg.fullTrajectory.tLiftoff = tLiftoff;
Leg.fullTrajectory.tTouchdown = tTouchdown;

%% Get the modified (averaged/unaveraged trimmed) motion and forces as specified by user selections in main
if dataExtraction.averageStepsForCyclicalMotion
    fprintf('Computing average relative motion of end effectors over one step. \n');
    % motion
    [meanCyclicMotionHipEE, cyclicMotionHipEE, meanCyclicC_IBody, samplingStart, samplingEnd, base.position] = getHipEECyclicData(tLiftoff, relativeMotionHipEE, removalRatioStart, removalRatioEnd, dt, minStepCount, C_IBody, EEnames, trajectoryData, legCount);    

else % do not average the motion, rather use the full motion, trimmed at start and end by removal ratios
    [meanCyclicMotionHipEE, meanCyclicC_IBody, base.position] = getHipEEFullMotionData(relativeMotionHipEE, removalRatioStart, removalRatioEnd, C_IBody, EEnames, trajectoryData, legCount);
end

for i = 1:legCount
    EEselection = EEnames(i,:); 
    % Base position synchronized with leg over its cycle. This is a subset
    % of the full trajectory base position.
    Leg.base.position.(EEselection) = base.position.(EEselection);
    % Base velocity from finite differences of base position. The posit
    Leg.base.velocity.(EEselection) = diff(Leg.base.position.(EEselection))/dt;
    % EE forces
    Leg.(EEselection).force = meanCyclicMotionHipEE.(EEselection).force;
end

% get the liftoff and touchdown indices for the new data.
for i = 1:legCount
    EEselection = EEnames(i,:);
    [tLiftoff.(EEselection), tTouchdown.(EEselection), ~] = getEELiftoffTouchdownTimings(Leg.time, Leg.(EEselection).force);
    Leg.(EEselection).tLiftoff = tLiftoff.(EEselection);
    Leg.(EEselection).tTouchdown = tTouchdown.(EEselection);    
end


%% qAFE, qDFE torque based heuristic computation
% compute the liftoff angle between the final link and the horizontal to
% satisfy the input requirement of thetaLiftoff_des. If this heuristic is
% used, the IK is solved using joint torque from previous timestep to
% define the joint deformation at the current timestep.
if (heuristic.torqueAngle.apply == true) && (linkCount > 2)
    fprintf('Computing joint angles for desired EE liftoff angle. \n');
    for i = 1:legCount
        EEselection = EEnames(i,:);
        % Use inverse kinematics to solve joint angles for first time step.
        [qLiftoff.(EEselection)] = computeqLiftoffFinalJoint(heuristic, Leg.(EEselection).hipAttachmentOffset, linkCount, meanCyclicMotionHipEE, robotProperties, EEselection, configSelection, hipParalleltoBody);
        EE_force = Leg.(EEselection).force(1,1:3);
        rotBodyY = -meanCyclicMotionHipEE.body.eulerAngles.(EEselection)(1,2); % rotation of body about inertial y
        qPrevious = qLiftoff.(EEselection);
    end
    else
        qLiftoff.(EEselection) = 0;
end

%% Inverse kinematics
fprintf('Computing joint angles using inverse kinematics.\n');
for i = 1:legCount
    EEselection = EEnames(i,:);
    [Leg.(EEselection).q, Leg.(EEselection).r.HAA, Leg.(EEselection).r.HFE, Leg.(EEselection).r.KFE, Leg.(EEselection).r.AFE, Leg.(EEselection).r.DFE, Leg.(EEselection).r.EE]  = inverseKinematics(heuristic, qLiftoff, Leg.(EEselection).hipAttachmentOffset, linkCount, meanCyclicMotionHipEE, robotProperties, EEselection, dataSelection, configSelection, hipParalleltoBody);
     Leg.(EEselection).r.EEdes = meanCyclicMotionHipEE.(EEselection).position(1:end,:); % save desired EE position in the same struct for easy comparison
end

%% Build robot rigid body model
fprintf('Creating and visualizing robot rigid body model. \n');
optimized = false; % For title of figure, differentiate between nominal and optimized leg.
for i = 1:legCount
    EEselection = EEnames(i,:);
    Leg.(EEselection).rigidBodyModel = buildRobotRigidBodyModel(actuatorProperties, actuateJointDirectly, Leg.(EEselection).hipAttachmentOffset, linkCount, robotProperties, Leg, meanCyclicMotionHipEE, EEselection, numberOfStepsVisualized, viewVisualization, hipParalleltoBody, dataExtraction, optimized, saveFiguresToPDF);
end

%% Get joint velocities with finite differences
fprintf('Computing joint velocities and accelerations. \n');
for i = 1:legCount
    EEselection = EEnames(i,:);
    [Leg.(EEselection).qdot, Leg.(EEselection).qdotdot] = getJointVelocitiesUsingFiniteDifference(EEselection, Leg, dt);
    Leg.(EEselection).q = Leg.(EEselection).q(1:end-2,:); % remove the two supplementary points for position after solving for joint speed and acceleration 
    % Smoothen the velocity and acceleration data using moving average filter
    for j = 1:length(Leg.(EEselection).qdot(1,:))
        Leg.(EEselection).qdot(:,j) = smooth(Leg.(EEselection).qdot(:,j));
        Leg.(EEselection).qdotdot(:,j) = smooth(Leg.(EEselection).qdotdot(:,j));
    end
end

%% Get joint torques using inverse dynamics
fprintf('Computing joint torques using inverse dynamics. \n');
for i = 1:legCount
    EEselection = EEnames(i,:);
    Leg.(EEselection).jointTorque = inverseDynamics(EEselection, Leg, meanCyclicMotionHipEE, linkCount);
    % Smoothen the torque data using moving average filter
    for j = 1:length(Leg.(EEselection).jointTorque(1,:))
        Leg.(EEselection).jointTorque(:,j) = smooth(Leg.(EEselection).jointTorque(:,j));
    end
end

%% Get joint power -> this is the mechanical power required at the joint
fprintf('Computing joint power. \n');
for i = 1:legCount
    EEselection = EEnames(i,:);
    Leg.(EEselection).jointPower = Leg.(EEselection).jointTorque .* Leg.(EEselection).qdot(:,1:end-1);
end

%% Get active and passive torques for spring modeled in parallel with joint
for i = 1:legCount
    EEselection = EEnames(i,:);    
    if springInParallelWithJoints
        q0SpringJoint.(EEselection) = mean(Leg.(EEselection).q(:,1:end-1)); % Set undeformed spring position to mean position. This can be updated in optimizer.
        [Leg.(EEselection).activeTorque, Leg.(EEselection).passiveTorque] = getActiveAndPassiveTorque(kSpringJoint, q0SpringJoint, Leg, EEselection, linkCount);
    else
        Leg.(EEselection).activeTorque = Leg.(EEselection).jointTorque;
        Leg.(EEselection).passiveTorque = 0;
    end  
end

%% Get actuator torque and speed as result of gearing between actuator and joint
% This is the required output torque and speed from the actuator to produce
% the joint torque and speed.
for i = 1:legCount
    EEselection = EEnames(i,:);
    if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
        selectFrontHind = 1;
    else
        selectFrontHind = 2;
    end
    for j = 1:jointCount
        % gear ratio = actuator speed / joint speed = joint torque/
        % actuator torque
        transmissionGearRatio = robotProperties.transmissionGearRatio.(jointNames(j,:))(selectFrontHind);
        Leg.(EEselection).actuatorq(:,j)      = transmissionGearRatio * Leg.(EEselection).q(:,j);
        Leg.(EEselection).actuatorqdot(:,j)   = transmissionGearRatio * Leg.(EEselection).qdot(:,j);
        Leg.(EEselection).actuatorTorque(:,j) = (1/transmissionGearRatio) * Leg.(EEselection).activeTorque(:,j);
    end
end

%% Get efficiency map of actuator
actuatorList = {actuatorSelection.HAA, actuatorSelection.HFE, actuatorSelection.KFE, actuatorSelection.AFE, actuatorSelection.DFE};
actuatorList = unique(actuatorList); % remove duplicates so we only solve the efficiency map once for each type of actuator
for i = 1:length(actuatorList)
    actuatorName = actuatorList(i);
    [actuatorEfficiency.(actuatorName{1}), efficiencyMapPlot.(actuatorName{1})] = getActuatorEfficiencySimplified(actuatorName);
    Leg.efficiencyMap.(actuatorName{1}) = efficiencyMapPlot.(actuatorName{1});
end

%% Get electrical power and efficiency at each operating point
fprintf('Computing electrical power and motor operating point efficiency. \n');
for i = 1:legCount
    EEselection = EEnames(i,:);
    [Leg.(EEselection).electricalPower, Leg.(EEselection).operatingPointEfficiency] = computeElectricalPowerInput(Leg, EEselection, actuatorProperties, linkCount, actuatorEfficiency, actuatorSelection);
    Leg.metaParameters.operatingPointEfficiencyMean.(EEselection) = mean(Leg.(EEselection).operatingPointEfficiency);
end

%% Save link lengths and mass
for i = 1:legCount
    EEselection = EEnames(i,:);
    if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
         selectFrontHind = 1;
     else
         selectFrontHind = 2;
     end
    Leg.(EEselection).linkMass = [robotProperties.hip(selectFrontHind).mass, ...
                                  robotProperties.thigh(selectFrontHind).mass, ...
                                  robotProperties.shank(selectFrontHind).mass];
    Leg.(EEselection).EEMass = robotProperties.EE(selectFrontHind).mass;
    
    if linkCount > 2
        Leg.(EEselection).linkMass(end+1) = robotProperties.foot(selectFrontHind).mass;
    end
    if linkCount > 3
        Leg.(EEselection).linkMass(end+1) = robotProperties.phalanges(selectFrontHind).mass;
    end

    Leg.(EEselection).totalLinkMass = sum(Leg.(EEselection).linkMass);
end
%% Get meta parameters
Leg.CoM.velocity = trajectoryData.base.velocity(floor(removalRatioStart*length(trajectoryData.base.velocity))+1:floor((1-removalRatioEnd)*length(trajectoryData.base.velocity)),:);
Leg.metaParameters.CoT.total = 0; % initialize total cost of transport

for i = 1:legCount
    EEselection = EEnames(i,:);
   
    % Cost of transport
    power = Leg.(EEselection).jointPower;
    Leg.metaParameters.CoT.(EEselection) = getCostOfTransport(Leg, power, robotProperties);
   
    % Add contribution of each leg to get the total CoT
    Leg.metaParameters.CoT.total = Leg.metaParameters.CoT.total + Leg.metaParameters.CoT.(EEselection); 
    
    % Power quality
    Leg.metaParameters.powerQuality.(EEselection) = computePowerQuality(power);

    % Max joint states
    [Leg.metaParameters.deltaqMax.(EEselection), Leg.metaParameters.qdotMax.(EEselection), Leg.metaParameters.jointTorqueMax.(EEselection), Leg.metaParameters.jointPowerMax.(EEselection)]  = getMaximumJointStates(Leg, EEselection);
    
    % Maximum actuator states
    for j = 1:linkCount+1
        if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
            selectFrontHind = 1;
        else
            selectFrontHind = 2;
        end
        transmissionGearRatio = robotProperties.transmissionGearRatio.(jointNames(j,:))(selectFrontHind);
        Leg.metaParameters.actuatordeltaqMax.(EEselection)(j) = transmissionGearRatio * Leg.metaParameters.deltaqMax.(EEselection)(j);
        Leg.metaParameters.actuatorqdotMax.(EEselection)(j)   = transmissionGearRatio *  Leg.metaParameters.qdotMax.(EEselection)(j);
        Leg.metaParameters.actuatorTorqueMax.(EEselection)(j) = (1/transmissionGearRatio) * Leg.metaParameters.jointTorqueMax.(EEselection)(j);
    end

    % Energy consumption
    [Leg.(EEselection).mechEnergy, Leg.metaParameters.mechEnergyPerCycle.(EEselection), Leg.(EEselection).elecEnergy, Leg.metaParameters.elecEnergyPerCycle.(EEselection)]  = computeEnergyConsumption(Leg.(EEselection).jointPower, Leg.(EEselection).electricalPower, dt);
    Leg.metaParameters.mechEnergyPerCycleTotal.(EEselection) = sum(Leg.metaParameters.mechEnergyPerCycle.(EEselection));
    Leg.metaParameters.elecEnergyPerCycleTotal.(EEselection) = sum(Leg.metaParameters.elecEnergyPerCycle.(EEselection));    
   
    % phase durations computed taking average of phase duration for each
    % step in full trajectory
%     [Leg.metaParameters.swingDuration.(EEselection), Leg.metaParameters.stanceDuration.(EEselection), Leg.metaParameters.swingDurationRatio.(EEselection)] = computePhaseDurations(Leg, EEselection);
end

%% Optimize selected legs and compute their cost of transport
if runOptimization % master toggle in main
    % Get actuator limits which are enforced by the optimizer
    for i = 1:jointCount
        jointSelection = jointNames(i,:);
        actuatorName = actuatorSelection.(jointSelection);
        if imposeJointLimits.maxTorque || imposeJointLimits.maxqdot || imposeJointLimits.maxPower
            [optimizationProperties.bounds.maxTorqueLimit.(jointSelection), optimizationProperties.bounds.maxqdotLimit.(jointSelection), optimizationProperties.bounds.maxPowerLimit.(jointSelection), ~, ~, ~, ~] = getActuatorProperties(actuatorName);
        end
    end
    
    %% Optimize the legs selected for optimization in main
    Leg.metaParameters.CoTOpt.total = 0;
    for i = 1:legCount
            EEselection = EEnames(i,:);
            if strcmp(EEselection,'LF') || strcmp(EEselection,'RF')
                selectFrontHind = 1;
            else
                selectFrontHind = 2;
            end
            
        % run optimization    
        if optimizeLeg.(EEselection) % Toggle in main to select legs for optimization
            fprintf('\nInitiating optimization of link lengths for %s\n', EEselection);
             % Evolve leg and return joint data of optimized design
            optimizationResults = evolveAndVisualizeOptimalLeg(actuatorProperties, imposeJointLimits, heuristic, actuateJointDirectly, Leg.(EEselection).hipAttachmentOffset, linkCount, optimizationProperties, EEselection, meanCyclicMotionHipEE, robotProperties, configSelection, dt, dataSelection, hipParalleltoBody, Leg, actuatorEfficiency, actuatorSelection, dataExtraction, jointNames, saveFiguresToPDF);

            % Save all the results of the optimization
            Leg.(EEselection).jointTorqueOpt                                 = optimizationResults.jointTorqueOpt;
            Leg.(EEselection).qOpt                                           = optimizationResults.qOpt;
            Leg.(EEselection).qdotOpt                                        = optimizationResults.qdotOpt;
            Leg.(EEselection).qdotdotOpt                                     = optimizationResults.qdotdotOpt;
            Leg.(EEselection).rOpt                                           = optimizationResults.rOpt;
            Leg.(EEselection).jointPowerOpt                                  = optimizationResults.jointPowerOpt;
            Leg.(EEselection).linkLengthsOpt                                 = optimizationResults.linkLengthsOpt;
            Leg.(EEselection).hipOffsetOpt                                   = optimizationResults.hipOffsetOpt;
            Leg.(EEselection).transmissionGearRatioOpt                       = optimizationResults.transmissionGearRatioOpt;
            Leg.(EEselection).penaltyMinOpt                                  = optimizationResults.penaltyMinOpt;
            Leg.metaParameters.elapsedTime.(EEselection)                     = optimizationResults.elapsedTime;
            Leg.metaParameters.elapsedTimePerFuncEval.(EEselection)          = optimizationResults.elapsedTimePerFuncEval;
            Leg.optimizationProperties.gaSettings.(EEselection)              = optimizationResults.gaSettings;
            Leg.(EEselection).linkMassOpt                                    = optimizationResults.linkMassOpt;
            Leg.(EEselection).totalLinkMassOpt                               = optimizationResults.totalLinkMassOpt;
            Leg.metaParameters.deltaqMaxOpt.(EEselection)                    = optimizationResults.deltaqMaxOpt; 
            Leg.metaParameters.qdotMaxOpt.(EEselection)                      = optimizationResults.qdotMaxOpt;
            Leg.metaParameters.jointTorqueMaxOpt.(EEselection)               = optimizationResults.jointTorqueMaxOpt;
            Leg.metaParameters.jointPowerMaxOpt.(EEselection)                = optimizationResults.jointPowerMaxOpt; 
            Leg.(EEselection).mechEnergyOpt                                  = optimizationResults.mechEnergyOpt;
            Leg.metaParameters.mechEnergyPerCycleOpt.(EEselection)           = optimizationResults.mechEnergyPerCycleOpt;
            Leg.metaParameters.mechEnergyPerCycleTotalOpt.(EEselection)      = optimizationResults.mechEnergyPerCycleTotalOpt;
            Leg.(EEselection).elecEnergyOpt                                  = optimizationResults.elecEnergyOpt;
            Leg.metaParameters.elecEnergyPerCycleOpt.(EEselection)           = optimizationResults.elecEnergyPerCycleOpt;
            Leg.metaParameters.elecEnergyPerCycleTotalOpt.(EEselection)      = optimizationResults.elecEnergyPerCycleTotalOpt;
            Leg.(EEselection).elecPowerOpt                                   = optimizationResults.elecPowerOpt;
            Leg.(EEselection).operatingPointEfficiencyOpt                    = optimizationResults.operatingPointEfficiencyOpt;
            Leg.metaParameters.operatingPointEfficiencyMeanOpt.(EEselection) = optimizationResults.operatingPointEfficiencyMeanOpt;
            Leg.(EEselection).spring.optimizedParameters.kTorsionalSpring    = optimizationResults.springOpt.kTorsionalSpring;
            Leg.(EEselection).spring.optimizedParameters.thetaLiftoff_des    = optimizationResults.springOpt.thetaLiftoff_des;                
            Leg.(EEselection).actuatorqOpt                                   = optimizationResults.actuatorqOpt;
            Leg.(EEselection).actuatorqdotOpt                                = optimizationResults.actuatorqdotOpt;
            Leg.(EEselection).actuatorTorqueOpt                              = optimizationResults.actuatorTorqueOpt;
            Leg.metaParameters.actuatordeltaqMaxOpt.(EEselection)            = optimizationResults.actuatordeltaqMaxOpt;
            Leg.metaParameters.actuatorqdotMaxOpt.(EEselection)              = optimizationResults.actuatorqdotMaxOpt;
            Leg.metaParameters.actuatorTorqueMaxOpt.(EEselection)            = optimizationResults.actuatorTorqueMaxOpt;

            % compute CoT
             power = Leg.(EEselection).jointPowerOpt;
             Leg.metaParameters.CoTOpt.(EEselection) = getCostOfTransport(Leg, power, robotProperties);
             Leg.metaParameters.powerQualityOpt.(EEselection) = computePowerQuality(power);
        end
    end
end
end
