/*
Project Orleans Cloud Service SDK ver. 1.0
 
Copyright (c) Microsoft Corporation
 
All rights reserved.
 
MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and 
associated documentation files (the ""Software""), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

using System;

namespace Orleans
{
    namespace Concurrency
    {
        /// <summary>
        /// The ReadOnly attribute is used to mark methods that do not modify the state of a grain.
        /// <para>
        /// Marking methods as ReadOnly allows the run-time system to perform a number of optimizations
        /// that may significantly improve the performance of your application.
        /// </para>
        /// </summary>
        [AttributeUsage(AttributeTargets.Method)]
        internal sealed class ReadOnlyAttribute : Attribute
        {
        }

        /// <summary>
        /// The Reentrant attribute is used to mark grain implementation classes that allow request interleaving within a task.
        /// <para>
        /// This is an advanced feature and should not be used unless the implications are fully understood.
        /// That said, allowing request interleaving allows the run-time system to perform a number of optimizations
        /// that may significantly improve the performance of your application. 
        /// </para>
        /// </summary>
        [AttributeUsage(AttributeTargets.Class)]
        public sealed class ReentrantAttribute : Attribute
        {
        }

        /// <summary>
        /// The Unordered attribute is used to mark grain interface in which the delivery order of
        /// messages is not significant.
        /// </summary>
        [AttributeUsage(AttributeTargets.Interface)]
        public sealed class UnorderedAttribute : Attribute
        {
        }

        /// <summary>
        /// The StatelessWorker attribute is used to mark grain class in which there is no expectation
        /// of preservation of grain state between requests and where multiple activations of the same grain are allowed to be created by the runtime. 
        /// </summary>
        [AttributeUsage(AttributeTargets.Class)]
        public sealed class StatelessWorkerAttribute : Attribute
        {
            /// <summary>
            /// Maximal number of local StatelessWorkers in a single silo.
            /// </summary>
            public int MaxLocalWorkers { get; private set; }

            public StatelessWorkerAttribute(int maxLocalWorkers)
            {
                MaxLocalWorkers = maxLocalWorkers;
            }

            public StatelessWorkerAttribute()
            {
                MaxLocalWorkers = -1;
            }
        }

        /// <summary>
        /// The AlwaysInterleaveAttribute attribute is used to mark methods that can interleave with any other method type, including write (non ReadOnly) requests.
        /// </summary>
        /// <remarks>
        /// Note that this attribute is applied to method declaration in the grain interface, 
        /// and not to the method in the implementation class itself.
        /// </remarks>
        [AttributeUsage(AttributeTargets.Method)]
        public sealed class AlwaysInterleaveAttribute : Attribute
        {
        }

        /// <summary>
        /// The Immutable attribute indicates that instances of the marked class or struct are never modified
        /// after they are created.
        /// </summary>
        /// <remarks>
        /// Note that this implies that sub-objects are also not modified after the instance is created.
        /// </remarks>
        [AttributeUsage(AttributeTargets.Struct | AttributeTargets.Class)]
        public sealed class ImmutableAttribute : Attribute
        {
        }
    }

    namespace Placement
    {
        using Orleans.Runtime;

        /// <summary>
        /// Base for all placement policy marker attributes.
        /// </summary>
        [AttributeUsage(AttributeTargets.Class, AllowMultiple = false)]
        public abstract class PlacementAttribute : Attribute
        {
            internal PlacementStrategy PlacementStrategy { get; private set; }

            internal PlacementAttribute(PlacementStrategy placement)
            {
                PlacementStrategy = placement ?? PlacementStrategy.GetDefault();
            }
        }

        /// <summary>
        /// Marks a grain class as using the <c>RandomPlacement</c> policy.
        /// </summary>
        /// <remarks>
        /// This is the default placement policy, so this attribute does not need to be used for normal grains.
        /// </remarks>
        [AttributeUsage(AttributeTargets.Class, AllowMultiple = false)]
        public sealed class RandomPlacementAttribute : PlacementAttribute
        {
            public RandomPlacementAttribute() :
                base(RandomPlacement.Singleton)
            { }
        }

        /// <summary>
        /// Marks a grain class as using the <c>PreferLocalPlacement</c> policy.
        /// </summary>
        [AttributeUsage(AttributeTargets.Class, AllowMultiple = false) ]
        public sealed class PreferLocalPlacementAttribute : PlacementAttribute
        {
            public PreferLocalPlacementAttribute() :
                base(PreferLocalPlacement.Singleton)
            { }
        }

        /// <summary>
        /// Marks a grain class as using the <c>ActivationCountBasedPlacement</c> policy.
        /// </summary>
        [AttributeUsage(AttributeTargets.Class, AllowMultiple = false)]
        public sealed class ActivationCountBasedPlacementAttribute : PlacementAttribute
        {
            public ActivationCountBasedPlacementAttribute() :
                base(ActivationCountBasedPlacement.Singleton)
            { }
        }
    }

    namespace CodeGeneration
    {
        /// <summary>
        /// The TypeCodeOverrideAttribute attribute allows to specify the grain interface ID or the grain class type code
        /// to override the default ones to avoid hash collisions
        /// </summary>
        [AttributeUsage(AttributeTargets.Interface | AttributeTargets.Class)]
        public sealed class TypeCodeOverrideAttribute : Attribute
        {
            /// <summary>
            /// Use a specific grain interface ID or grain class type code (e.g. to avoid hash collisions)
            /// </summary>
            public int TypeCode { get; private set; }

            public TypeCodeOverrideAttribute(int typeCode)
            {
                TypeCode = typeCode;
            }
    }

    /// <summary>
    /// Used to mark a method as providing a copier function for that type.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class CopierMethodAttribute : Attribute
    {
    }

    /// <summary>
    /// Used to mark a method as providinga serializer function for that type.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class SerializerMethodAttribute : Attribute
    {
    }

    /// <summary>
    /// Used to mark a method as providing a deserializer function for that type.
    /// </summary>
    [AttributeUsage(AttributeTargets.Method)]
    public sealed class DeserializerMethodAttribute : Attribute
    {
    }

    /// <summary>
    /// Used to make a class for auto-registration as a serialization helper.
    /// </summary>
    [AttributeUsage(AttributeTargets.Class)]
    public sealed class RegisterSerializerAttribute : Attribute
    {
    }
    }

    namespace Providers
    {
        /// <summary>
        /// The [Orleans.Providers.StorageProvider] attribute is used to define which storage provider to use for persistence of grain state.
        /// <para>
        /// Specifying [Orleans.Providers.StorageProvider] property is recommended for all grains which extend Grain&lt;T&gt;.
        /// If no [Orleans.Providers.StorageProvider] attribute is  specified, then a "Default" strorage provider will be used.
        /// If a suitable storage provider cannot be located for this grain, then the grain will fail to load into the Silo.
        /// </para>
        /// </summary>
        [AttributeUsage(AttributeTargets.Class)]
        public sealed class StorageProviderAttribute : Attribute
        {
            public StorageProviderAttribute()
            {
                    ProviderName = Runtime.Constants.DEFAULT_STORAGE_PROVIDER_NAME;
            }
            /// <summary>
            /// The name of the storage provider to ne used for persisting state for this grain.
            /// </summary>
            public string ProviderName { get; set; }
        }
    }

    [AttributeUsage(AttributeTargets.Interface)]
    internal sealed class FactoryAttribute : Attribute
    {
        public enum FactoryTypes
        {
            Grain,
            ClientObject,
            Both
        };

        private readonly FactoryTypes factoryType;

        public FactoryAttribute(FactoryTypes factoryType)
        {
            this.factoryType = factoryType;
        }

        internal static FactoryTypes CollectFactoryTypesSpecified(Type type)
        {
            var attribs = type.GetCustomAttributes(typeof(FactoryAttribute), inherit: true);

            // if no attributes are specified, we default to FactoryTypes.Grain.
            if (0 == attribs.Length)
                return FactoryTypes.Grain;
            
            // otherwise, we'll consider all of them and aggregate the specifications
            // like flags.
            FactoryTypes? result = null;
            foreach (var i in attribs)
            {
                var a = (FactoryAttribute)i;
                if (result.HasValue)
                {
                    if (a.factoryType == FactoryTypes.Both)
                        result = a.factoryType;
                    else if (a.factoryType != result.Value)
                        result = FactoryTypes.Both;
                }
                else
                    result = a.factoryType;
            }

            if (result.Value == FactoryTypes.Both)
            {
                throw 
                    new NotSupportedException(
                        "Orleans doesn't currently support generating both a grain and a client object factory but we really want to!");
            }
            
            return result.Value;
        }

        public static FactoryTypes CollectFactoryTypesSpecified<T>()
        {
            return CollectFactoryTypesSpecified(typeof(T));
        }
    }

    [AttributeUsage(AttributeTargets.Class, AllowMultiple=true)]
    public sealed class ImplicitStreamSubscriptionAttribute : Attribute
    {
        internal string Namespace { get; private set; }

        // We have not yet come to an agreement whether the provider should be specified as well.
        public ImplicitStreamSubscriptionAttribute(string streamNamespace)
        {
            Namespace = streamNamespace;
        }
    }
}
