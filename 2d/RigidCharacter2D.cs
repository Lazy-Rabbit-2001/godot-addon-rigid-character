using Godot;
using System;
using static Godot.GD;

namespace GodotRigidCharacter;

[Icon("uid://dyd0heol7wple")]
public partial class RigidCharacter2D : CharacterBody2D
{
    public enum MotionBaseEnum { UpDirection, GlobalRotation };
    public enum MotionComponentEnum { X, Y };
    public enum UpDirectionBaseEnum { Default, GlobalRotation, ReversedGravityDirection };

    private float _mass = 1.0f;
    private float _gravityScale = 1.0f;
    private UpDirectionBaseEnum _upDirectionBase = UpDirectionBaseEnum.GlobalRotation;

    private Vector2 _prevVelocity = Vector2.Zero;
    private bool _prevWasOnFloor = false;
    private Vector2 _prevNormal = Vector2.Zero;

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
            PhysicsServer2D.BodySetParam(GetRid(), PhysicsServer2D.BodyParameter.Mass, _mass);
        }
    }
    [Export]
    public MotionBaseEnum MotionBase { get; set; } = MotionBaseEnum.UpDirection;
    [Export(PropertyHint.None, "suffix:px/s")]
    public Vector2 Motion
    {
        get => MotionBase == MotionBaseEnum.UpDirection && MotionMode == MotionModeEnum.Grounded ? Velocity.Rotated(-UpDirectionRotation) : Velocity.Rotated(-GlobalRotation);
        set => Velocity = MotionBase == MotionBaseEnum.UpDirection && MotionMode == MotionModeEnum.Grounded ? value.Rotated(UpDirectionRotation) : value.Rotated(GlobalRotation);
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
            PhysicsServer2D.BodySetParam(GetRid(), PhysicsServer2D.BodyParameter.GravityScale, _gravityScale);
        }
    }
    [Export(PropertyHint.Range, "0.0, 9999.9, 0.1, or_greater, hide_slider, suffix:px/s")]
    public float MaxFallingSpeed { get; set; } = 1500.0f;

    [ExportGroup("Rotation Sync")]
    [Export]
    public bool RotationSyncEnabled { get; set; } = true;
    [Export(PropertyHint.Range, "0.0, 360.0, 0.1, or_greater, radians_as_degrees, suffix:°/s")]
    public double RotationSyncSpeed { get; set; } = Math.Tau;

    public Vector2 Momentum
    {
        get => Velocity * Mass;
        set => Velocity = value / Mass;
    }

    public float UpDirectionRotation
    {
        get => Vector2.Up.AngleTo(UpDirection);
    }
    public Vector2 PreviousVelocity
    {
        get => _prevVelocity;
    }

    protected virtual bool _Move(float speedScale)
    {
        _prevVelocity = Velocity;
        _prevWasOnFloor = IsOnFloor();

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

        SyncGlobalRotation();

        Velocity *= speedScale;
        var ret = MoveAndSlide();
        Velocity /= speedScale;

        return ret;
    }

    public void Accelerate(Vector2 acceleration) => Velocity += acceleration * (float)BodyDelta;
    public void Accelerate(Vector2 acceleration, Vector2 targetVelocity) => Velocity = Velocity.MoveToward(targetVelocity, acceleration.Length() * (float)BodyDelta);
    public void AccelerateMotion(Vector2 acceleration) => Motion += acceleration * (float)BodyDelta;
    public void AccelerateMotion(Vector2 acceleration, Vector2 targetMotion) => Motion = Motion.MoveToward(targetMotion, acceleration.Length() * (float)BodyDelta);
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
    public void ApplyForce(Vector2 force) => Momentum += force * (float)BodyDelta;
    public void ApplyImpulse(Vector2 impulse) => Momentum += impulse;
    public void ApplyVelocity(Vector2 vector) => Velocity += vector;
    public void Bounce()
    {
        if (_prevNormal.IsZeroApprox() || !_prevNormal.IsFinite()) return;

        Velocity = (_prevVelocity.IsZeroApprox() ? Velocity : _prevVelocity).Bounce(_prevNormal);
    }
    public float GetFloorFriction()
    {
        if (!IsOnFloor()) return 0.0f;

        var kc = new KinematicCollision2D();
        TestMove(GlobalTransform, GetGravity().Normalized() * FloorSnapLength, kc);

        if (kc is not null && kc.GetCollider() is not null)
            return (float)PhysicsServer2D.BodyGetParam(kc.GetColliderRid(), PhysicsServer2D.BodyParameter.Friction);
        
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

        var gdr = PhysicsServer2D.AreaGetParam(GetViewport().FindWorld2D().Space, PhysicsServer2D.AreaParameter.GravityVector).As<Vector2>().AngleTo(GetGravity());
        var isRotationEqualApprox = Mathf.IsEqualApprox(GlobalRotation, gdr);

        if (GlobalRotation != gdr && (IsOnFloor() || _prevWasOnFloor || isRotationEqualApprox))
            GlobalRotation = gdr;
        else if (!isRotationEqualApprox)
            GlobalRotation = Mathf.Lerp(GlobalRotation, gdr, (float)RotationSyncSpeed * (float)BodyDelta);
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
        if (MotionMode == MotionModeEnum.Floating)
        {
            PrintErr("The property 'UpDirectionBase' can only be set when the motion mode is 'Grounded'.");
            return;
        }

        switch (_upDirectionBase)
        {
            case UpDirectionBaseEnum.GlobalRotation:
                UpDirection = Vector2.Up.Rotated(GlobalRotation);
                break;
            case UpDirectionBaseEnum.ReversedGravityDirection:
                UpDirection = -GetGravity().Normalized();
                break;
            default:
                break;
        }
    }


    public RigidCharacter2D()
    {
        Mass = _mass;
        GravityScale = _gravityScale;
    }
}