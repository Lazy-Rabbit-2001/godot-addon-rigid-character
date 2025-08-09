using Godot;
using System;
using static Godot.GD;

namespace GodotRigidCharacter;

[Icon("uid://bur51fsaaek32")]
public partial class RigidCharacter3D : CharacterBody3D
{
    public enum MotionComponentEnum { X, Y };
    public enum UpDirectionBaseEnum { Default, ReversedGravityDirection };

    private float _mass = 1.0f;
    private float _gravityScale = 1.0f;
    private UpDirectionBaseEnum _upDirectionBase = UpDirectionBaseEnum.ReversedGravityDirection;

    private bool _updateUpDirectionFromInner = false;
    private Vector3 _prevVelocity = Vector3.Zero;
    private bool _prevOnFloor = false;
    private Vector3 _prevNormal = Vector3.Zero;

    protected double BodyDelta
    {
        get => Engine.IsInPhysicsFrame() ? GetPhysicsProcessDeltaTime() : GetProcessDeltaTime();
    }

    [Export(PropertyHint.Range, "0.0, 9999.9, 0.1, or_greater, hide_slider, suffix:kg")]
    public float Mass
    {
        get => _mass;
        set
        {
            _mass = value;
            PhysicsServer3D.BodySetParam(GetRid(), PhysicsServer3D.BodyParameter.Mass, _mass);
        }
    }
    [Export(PropertyHint.None, "suffix:px/s")]
    public Vector3 Motion
    {
        get => (MotionMode == MotionModeEnum.Grounded ? UpDirectionRotation : GlobalBasis.GetRotationQuaternion().Inverse()).Inverse() * Velocity;
        set => Velocity = (MotionMode == MotionModeEnum.Grounded ? UpDirectionRotation : GlobalBasis.GetRotationQuaternion()) * value;
    }
    [Export]
    public UpDirectionBaseEnum UpDirectionBase
    {
        get => _upDirectionBase;
        set
        {
            _upDirectionBase = value;
            UpdateUpDirection();
        }
    }

    [ExportGroup("Gravity")]
    [Export(PropertyHint.Range, "-8.0, 8.0, 0.1, or_greater, or_less")]
    public float GravityScale
    {
        get => _gravityScale;
        set
        {
            _gravityScale = value;
            PhysicsServer3D.BodySetParam(GetRid(), PhysicsServer3D.BodyParameter.GravityScale, _gravityScale);
        }
    }
    [Export(PropertyHint.Range, "0.0, 9999.9, 0.1, or_greater, hide_slider, suffix:px/s")]
    public float MaxFallingSpeed { get; set; } = 1500.0f;

    [ExportGroup("Rotation Sync")]
    [Export]
    public bool RotationSyncEnabled { get; set; } = true;
    [Export(PropertyHint.Range, "0.0, 360.0, 0.1, or_greater, radians_as_degrees, suffix:°/s")]
    public double RotationSyncSpeed { get; set; } = Math.Tau;

    public Vector3 Momentum
    {
        get => Velocity * Mass;
        set => Velocity = value / Mass;
    }

    public Quaternion UpDirectionRotation
    {
        get
        {
            // Code arranged from https://ghostyii.com/ringworld/ by Ghostyii.
            // Inspired and shared by https://forum.godotengine.org/t/3d-moving-around-sphere/63674/4 by militaryg.
            var currentBasis = Engine.IsEditorHint() ? Basis : GlobalBasis;
            return MotionMode == MotionModeEnum.Grounded
               ? currentBasis.GetRotationQuaternion()
               : (new Quaternion(currentBasis.Y.Normalized(), UpDirection) * currentBasis.GetRotationQuaternion()).Normalized();
        }
    }
    public Vector3 PreviousVelocity => _prevVelocity;

    protected virtual bool _Move(float speedScale)
    {
        _prevVelocity = Velocity;
        _prevOnFloor = IsOnFloor();

        var lastSlideCollision = GetLastSlideCollision();
        if (lastSlideCollision is not null)
            _prevNormal = lastSlideCollision.GetNormal();

        UpdateUpDirection(); // Triggers the setter to update the up direction.

        var g = GetGravity();
        var gdir = g.Normalized();

        if (!Mathf.IsZeroApprox(GravityScale))
        {
            Velocity += g * GravityScale * (float)BodyDelta;

            var fallingVel = Velocity.Project(gdir);
            if (fallingVel.LengthSquared() > Math.Pow(MaxFallingSpeed, 2.0))
                Velocity += fallingVel.Normalized() * MaxFallingSpeed - fallingVel;
        }

        _updateUpDirectionFromInner = true;
        SyncGlobalRotation();

        Velocity *= speedScale;
        var ret = MoveAndSlide();
        Velocity /= speedScale;

        return ret;
    }

    public void Accelerate(Vector3 acceleration) => Velocity += acceleration * (float)BodyDelta;
    public void Accelerate(Vector3 acceleration, Vector3 targetVelocity) => Velocity = Velocity.MoveToward(targetVelocity, acceleration.Length() * (float)BodyDelta);
    public void AccelerateMotion(Vector3 acceleration) => Motion += acceleration * (float)BodyDelta;
    public void AccelerateMotion(Vector3 acceleration, Vector3 targetMotion) => Motion = Motion.MoveToward(targetMotion, acceleration.Length() * (float)BodyDelta);
    public void AccelerateMotionComponent(MotionComponentEnum component, double acceleration)
    {
        var newMotion = Motion;
        newMotion[(ushort)component] += (float)(acceleration * BodyDelta);
        Motion = newMotion;
    }
    public void AccelerateMotionComponent(MotionComponentEnum component, double acceleration, double targetMotionComponent)
    {
        var newMotion = Motion;
        newMotion[(ushort)component] = Mathf.MoveToward(newMotion[(ushort)component], (float)targetMotionComponent, (float)(acceleration * BodyDelta));
        Motion = newMotion;
    }
    public void ApplyForce(Vector3 force) => Momentum += force * (float)BodyDelta;
    public void ApplyImpulse(Vector3 impulse) => Momentum += impulse;
    public void ApplyVelocity(Vector3 vector) => Velocity += vector;
    public void Bounce()
    {
        if (_prevNormal.IsZeroApprox() || !_prevNormal.IsFinite()) return;

        Velocity = (_prevVelocity.IsZeroApprox() ? Velocity : _prevVelocity).Bounce(_prevNormal);
    }
    public float GetFloorFriction()
    {
        if (!IsOnFloor()) return 0.0f;

        var kc = new KinematicCollision3D();
        TestMove(GlobalTransform, GetGravity().Normalized() * FloorSnapLength, kc);

        if (kc is not null && kc.GetCollider() is not null)
            return (float)PhysicsServer3D.BodyGetParam(kc.GetColliderRid(), PhysicsServer3D.BodyParameter.Friction);
        
        return 0.0f;
    }
    public void Jump(float impulse, bool affectMomentum = true)
    {
        if (MotionMode == MotionModeEnum.Floating)
        {
            PrintErr("The method 'Jump()' can only be called when the motion mode is 'Floating'.");
            return;
        }

        var imp = affectMomentum ? Momentum.Project(UpDirection) : Velocity.Project(UpDirection);
        var result = impulse * imp.Normalized() - imp;

        if (affectMomentum) Momentum += result;
        else Velocity += result;
    }

    public bool Move(float speedScale = 1.0f) => _Move(speedScale);
    public void SyncGlobalRotation()
    {
        if (!RotationSyncEnabled) return;

        var grq = GlobalBasis.GetRotationQuaternion();

        if (IsOnFloor() || _prevOnFloor || grq.IsEqualApprox(UpDirectionRotation)) GlobalRotation = UpDirectionRotation.GetEuler(RotationOrder);
        else GlobalRotation = grq.Slerp(UpDirectionRotation, (float)(RotationSyncSpeed * BodyDelta)).GetEuler(RotationOrder);

        if (_updateUpDirectionFromInner)
        {
            _updateUpDirectionFromInner = false;
            return;
        }

        UpdateUpDirection();
    }
    public void Turn()
    {
        if (MotionMode == MotionModeEnum.Floating)
        {
            PrintErr("The method 'Turn()' can only be called when the motion mode is 'Grounded'.");
            return;
        }

        var v = _prevVelocity.IsZeroApprox() ? Velocity : _prevVelocity;

        if (IsOnFloor()) Velocity = v.Reflect(GetFloorNormal());
        else Velocity = v.Reflect(UpDirection);

    }
    public void UpdateUpDirection()
    {
        if (MotionMode == MotionModeEnum.Floating) return;
        if (UpDirectionBase == UpDirectionBaseEnum.ReversedGravityDirection && IsInsideTree()) UpDirection = -GetGravity().Normalized();
    }


    public RigidCharacter3D()
    {
        Mass = _mass;
        GravityScale = _gravityScale;
    }
}